"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import {
  AlertCircle,
  ArrowLeft,
  CheckCircle2,
  Clock,
  Disc,
  FileAudio,
  HardDrive,
  ImageIcon,
  Loader2,
  RefreshCw,
  Sparkles,
  UploadCloud,
  X,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { StatusBadge } from "@/components/ui/badge";
import { api } from "@/lib/api/client";
import { CreatorTrackDetail } from "@/types";

const ALLOWED_AUDIO_TYPES = [
  "audio/mpeg",
  "audio/mp3",
  "audio/wav",
  "audio/x-wav",
  "audio/flac",
  "audio/x-flac",
  "audio/mp4",
  "audio/x-m4a",
  "audio/aac",
  "audio/ogg",
];

const GENRE_OPTIONS = [
  "Ambient",
  "Electronic",
  "Hip-Hop",
  "Pop",
  "Rock",
  "Indie",
  "Classical",
  "Jazz",
  "Lo-Fi",
  "R&B",
  "Folk",
  "Metal",
  "Podcast",
];

export default function CreatorUploadPage() {
  const router = useRouter();

  // Audio File
  const [file, setFile] = React.useState<File | null>(null);
  const [fileError, setFileError] = React.useState<string | null>(null);

  // Artwork File
  const [artworkFile, setArtworkFile] = React.useState<File | null>(null);
  const [artworkPreview, setArtworkPreview] = React.useState<string | null>(null);

  // Metadata Form
  const [title, setTitle] = React.useState("");
  const [artistName, setArtistName] = React.useState("");
  const [album, setAlbum] = React.useState("");
  const [genre, setGenre] = React.useState("Electronic");
  const [description, setDescription] = React.useState("");

  // Upload & Progress State
  const [uploadPercent, setUploadPercent] = React.useState<number | null>(null);
  const [uploadState, setUploadState] = React.useState<
    "idle" | "uploading" | "processing" | "completed" | "failed"
  >("idle");
  const [statusMessage, setStatusMessage] = React.useState<string | null>(null);
  const [errorMessage, setErrorMessage] = React.useState<string | null>(null);

  // Uploaded Track Reference
  const [uploadedTrack, setUploadedTrack] = React.useState<CreatorTrackDetail | null>(null);

  const fileInputRef = React.useRef<HTMLInputElement>(null);
  const artworkInputRef = React.useRef<HTMLInputElement>(null);

  // Polling for processing completion
  React.useEffect(() => {
    let timer: NodeJS.Timeout;
    if (uploadState === "processing" && uploadedTrack) {
      timer = setInterval(async () => {
        try {
          const detail = await api.studio.getTrackDetail(uploadedTrack.id);
          setUploadedTrack(detail);
          if (detail.status === "READY") {
            setUploadState("completed");
            setStatusMessage("Track transcoding complete! Ready for streaming and publishing.");
          } else if (detail.status === "FAILED") {
            setUploadState("failed");
            setStatusMessage("Transcoding failed. Review error logs below.");
          }
        } catch {
          // Ignore transient poll errors
        }
      }, 3000);
    }
    return () => clearInterval(timer);
  }, [uploadState, uploadedTrack]);

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      const selected = e.target.files[0];
      setFileError(null);

      // Validate file size (100MB limit)
      if (selected.size > 100 * 1024 * 1024) {
        setFileError(`File size (${(selected.size / (1024 * 1024)).toFixed(1)}MB) exceeds 100MB limit.`);
        return;
      }
      if (selected.size < 1000) {
        setFileError("File is too small or corrupted.");
        return;
      }

      setFile(selected);
      if (!title) {
        // Auto-fill title from filename
        const base = selected.name.replace(/\.[^/.]+$/, "");
        setTitle(base);
      }
    }
  };

  const handleArtworkChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      const img = e.target.files[0];
      if (!img.type.startsWith("image/")) {
        alert("Artwork must be a valid image file (JPEG, PNG, WebP).");
        return;
      }
      if (img.size > 5 * 1024 * 1024) {
        alert("Artwork image exceeds 5MB size limit.");
        return;
      }
      setArtworkFile(img);
      setArtworkPreview(URL.createObjectURL(img));
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!file) {
      setFileError("Please select a master audio file to upload.");
      return;
    }
    if (!title.trim()) {
      setErrorMessage("Track title is required.");
      return;
    }

    setUploadState("uploading");
    setUploadPercent(0);
    setErrorMessage(null);
    setStatusMessage("Streaming master audio to server...");

    try {
      const formData = new FormData();
      formData.append("file", file);
      formData.append("title", title.trim());
      if (artistName.trim()) formData.append("artist_name", artistName.trim());
      if (album.trim()) formData.append("album_name", album.trim());
      if (genre.trim()) formData.append("genre", genre.trim());
      if (description.trim()) formData.append("description", description.trim());

      // Execute upload with REAL XHR progress tracking
      const newTrackItem = await api.studio.uploadTrack(formData, (pct) => {
        setUploadPercent(pct);
        setStatusMessage(`Uploading master audio: ${pct}% transferred...`);
      });

      // If user provided artwork, upload it immediately
      if (artworkFile) {
        setStatusMessage("Applying cover artwork asset...");
        try {
          await api.studio.uploadTrackArtwork(newTrackItem.id, artworkFile);
        } catch (artErr) {
          console.error("Cover artwork failed during upload sequence", artErr);
        }
      }

      // Fetch full track detail to initialize processing state
      const initialDetail = await api.studio.getTrackDetail(newTrackItem.id);
      setUploadedTrack(initialDetail);

      if (initialDetail.status === "READY") {
        setUploadState("completed");
        setStatusMessage("Transcoding completed immediately!");
      } else {
        setUploadState("processing");
        setStatusMessage("Master audio received. Celery and FFmpeg workers are transcoding streams...");
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Failed to upload audio.";
      setErrorMessage(msg);
      setUploadState("idle");
      setUploadPercent(null);
    }
  };

  return (
    <div className="max-w-3xl mx-auto space-y-6">
      {/* Page Header */}
      <div className="flex items-center justify-between">
        <Link href="/studio/tracks">
          <Button variant="ghost" size="sm">
            <ArrowLeft className="h-4 w-4 mr-1.5" />
            Back to Media Library
          </Button>
        </Link>
      </div>

      <div>
        <h1 className="text-2xl font-bold tracking-tight text-white flex items-center gap-2">
          <span>Upload Audio & Media Ingestion</span>
        </h1>
        <p className="text-xs text-slate-400 mt-1">
          Master files are transcoded by background FFmpeg workers into multi-bitrate streams with waveforms and metadata.
        </p>
      </div>

      {/* Processing State View (shown after upload starts) */}
      {(uploadState === "processing" || uploadState === "completed" || uploadState === "failed") &&
        uploadedTrack && (
          <Card className="border-purple-800/80 bg-slate-900/90 shadow-2xl animate-in fade-in zoom-in-95">
            <CardHeader>
              <div className="flex items-center justify-between">
                <CardTitle className="text-base flex items-center gap-2">
                  {uploadState === "completed" ? (
                    <CheckCircle2 className="h-5 w-5 text-emerald-400" />
                  ) : uploadState === "failed" ? (
                    <AlertCircle className="h-5 w-5 text-rose-400" />
                  ) : (
                    <Loader2 className="h-5 w-5 animate-spin text-purple-400" />
                  )}
                  <span>
                    {uploadState === "completed"
                      ? "Ingestion Complete"
                      : uploadState === "failed"
                      ? "Transcode Failed"
                      : "Processing Media In Background"}
                  </span>
                </CardTitle>
                <StatusBadge status={uploadedTrack.status} />
              </div>
              <CardDescription>{statusMessage}</CardDescription>
            </CardHeader>
            <CardContent className="space-y-6">
              {/* Timeline steps */}
              <div className="grid grid-cols-1 md:grid-cols-3 gap-3 text-xs">
                <div className="p-3 rounded-lg bg-emerald-950/40 border border-emerald-800/60 flex items-center gap-2.5">
                  <CheckCircle2 className="h-4 w-4 text-emerald-400 shrink-0" />
                  <div>
                    <div className="font-semibold text-slate-200">1. Master Uploaded</div>
                    <div className="text-2xs text-slate-400">Audio asset verified</div>
                  </div>
                </div>

                <div
                  className={`p-3 rounded-lg border flex items-center gap-2.5 ${
                    uploadState === "completed"
                      ? "bg-emerald-950/40 border-emerald-800/60"
                      : uploadState === "failed"
                      ? "bg-rose-950/40 border-rose-800/60"
                      : "bg-purple-950/40 border-purple-800/60"
                  }`}
                >
                  {uploadState === "completed" ? (
                    <CheckCircle2 className="h-4 w-4 text-emerald-400 shrink-0" />
                  ) : uploadState === "failed" ? (
                    <AlertCircle className="h-4 w-4 text-rose-400 shrink-0" />
                  ) : (
                    <Loader2 className="h-4 w-4 animate-spin text-purple-400 shrink-0" />
                  )}
                  <div>
                    <div className="font-semibold text-slate-200">2. Transcoding</div>
                    <div className="text-2xs text-slate-400">
                      {uploadedTrack.renditions?.length || 0} renditions generated
                    </div>
                  </div>
                </div>

                <div
                  className={`p-3 rounded-lg border flex items-center gap-2.5 ${
                    uploadState === "completed"
                      ? "bg-emerald-950/40 border-emerald-800/60"
                      : "bg-slate-950/40 border-slate-800"
                  }`}
                >
                  {uploadState === "completed" ? (
                    <CheckCircle2 className="h-4 w-4 text-emerald-400 shrink-0" />
                  ) : (
                    <Clock className="h-4 w-4 text-slate-500 shrink-0" />
                  )}
                  <div>
                    <div className="font-semibold text-slate-200">3. Publishing Ready</div>
                    <div className="text-2xs text-slate-400">
                      {uploadState === "completed" ? "Streamable on Hums" : "Awaiting transcoding"}
                    </div>
                  </div>
                </div>
              </div>

              {/* Action Buttons */}
              <div className="flex flex-wrap items-center gap-3 pt-2">
                <Link href={`/studio/tracks/${uploadedTrack.id}`}>
                  <Button variant="primary" size="sm">
                    Open Track Detail Page
                  </Button>
                </Link>
                <Link href="/studio/tracks">
                  <Button variant="outline" size="sm">
                    View Media Library
                  </Button>
                </Link>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => {
                    setUploadState("idle");
                    setUploadedTrack(null);
                    setFile(null);
                    setArtworkFile(null);
                    setArtworkPreview(null);
                    setTitle("");
                  }}
                >
                  Upload Another Track
                </Button>
              </div>
            </CardContent>
          </Card>
        )}

      {/* Main Upload Form */}
      {uploadState === "idle" || uploadState === "uploading" ? (
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Master Audio Asset & Metadata</CardTitle>
            <CardDescription>
              Select lossless or high-bitrate master audio. Supports MP3, WAV, FLAC, M4A, AAC, OGG up to 100MB.
            </CardDescription>
          </CardHeader>
          <CardContent>
            {errorMessage && (
              <div className="mb-6 p-3.5 rounded-lg bg-rose-950/60 border border-rose-800 text-xs text-rose-300 flex items-center gap-2">
                <AlertCircle className="h-4 w-4 shrink-0" />
                <span>{errorMessage}</span>
              </div>
            )}

            {fileError && (
              <div className="mb-6 p-3.5 rounded-lg bg-amber-950/60 border border-amber-800 text-xs text-amber-300 flex items-center gap-2">
                <AlertCircle className="h-4 w-4 shrink-0" />
                <span>{fileError}</span>
              </div>
            )}

            {uploadState === "uploading" && (
              <div className="mb-6 p-4 rounded-xl bg-purple-950/50 border border-purple-800/80 space-y-2">
                <div className="flex items-center justify-between text-xs font-semibold text-purple-200">
                  <span>{statusMessage}</span>
                  <span className="font-mono">{uploadPercent !== null ? `${uploadPercent}%` : "Transferring..."}</span>
                </div>
                <div className="w-full h-2 rounded-full bg-slate-800 overflow-hidden">
                  <div
                    className="h-full bg-gradient-to-r from-purple-500 to-indigo-500 transition-all duration-150"
                    style={{ width: `${uploadPercent || 5}%` }}
                  />
                </div>
              </div>
            )}

            <form onSubmit={handleSubmit} className="space-y-6">
              {/* Audio Dropzone */}
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-2">
                  Master Audio File *
                </label>
                <div
                  onClick={() => fileInputRef.current?.click()}
                  className={`border-2 border-dashed rounded-xl p-8 text-center cursor-pointer transition-colors ${
                    file
                      ? "border-purple-600 bg-purple-950/20 hover:bg-purple-950/30"
                      : "border-slate-700 bg-slate-950/50 hover:border-purple-500 hover:bg-slate-900/50"
                  }`}
                >
                  <input
                    ref={fileInputRef}
                    type="file"
                    accept=".mp3,.wav,.flac,.m4a,.aac,.ogg,audio/*"
                    className="hidden"
                    onChange={handleFileChange}
                  />
                  <div className="flex flex-col items-center justify-center gap-2">
                    <div className="h-12 w-12 rounded-full bg-purple-900/40 border border-purple-700/60 flex items-center justify-center text-purple-300">
                      <FileAudio className="h-6 w-6" />
                    </div>
                    {file ? (
                      <div>
                        <span className="font-semibold text-sm text-purple-200 block">
                          {file.name}
                        </span>
                        <span className="text-xs text-slate-400">
                          {(file.size / (1024 * 1024)).toFixed(2)} MB • {file.type || "Audio Asset"}
                        </span>
                      </div>
                    ) : (
                      <div>
                        <span className="font-semibold text-sm text-slate-200 block">
                          Click to browse or drag & drop audio file
                        </span>
                        <span className="text-xs text-slate-500">
                          MP3, WAV, FLAC, M4A, AAC, OGG up to 100MB
                        </span>
                      </div>
                    )}
                  </div>
                </div>
              </div>

              {/* Cover Artwork Uploader (Optional) */}
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-2">
                  Cover Artwork (Optional)
                </label>
                <div className="flex items-center gap-4">
                  <div
                    onClick={() => artworkInputRef.current?.click()}
                    className="h-20 w-20 rounded-xl bg-slate-900 border border-slate-700 hover:border-purple-500 overflow-hidden flex items-center justify-center cursor-pointer text-slate-500 shrink-0 relative"
                  >
                    <input
                      ref={artworkInputRef}
                      type="file"
                      accept="image/jpeg,image/png,image/webp"
                      className="hidden"
                      onChange={handleArtworkChange}
                    />
                    {artworkPreview ? (
                      <img src={artworkPreview} alt="Preview" className="h-full w-full object-cover" />
                    ) : (
                      <ImageIcon className="h-6 w-6 text-slate-600" />
                    )}
                  </div>
                  <div className="text-xs text-slate-400 space-y-1">
                    <button
                      type="button"
                      onClick={() => artworkInputRef.current?.click()}
                      className="text-purple-400 hover:text-purple-300 font-medium block"
                    >
                      {artworkFile ? "Change Cover Image" : "Upload Cover Artwork"}
                    </button>
                    <span className="text-2xs text-slate-500 block">
                      JPEG, PNG, or WebP up to 5MB. Recommended minimum 1000x1000px.
                    </span>
                  </div>
                </div>
              </div>

              {/* Track Metadata Fields */}
              <div className="space-y-4">
                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1.5">
                    Track Title *
                  </label>
                  <Input
                    placeholder="e.g. Celestial Horizon"
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    required
                  />
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  <div>
                    <label className="block text-xs font-medium text-slate-300 mb-1.5">
                      Artist / Project Name
                    </label>
                    <Input
                      placeholder="e.g. Luna Wave"
                      value={artistName}
                      onChange={(e) => setArtistName(e.target.value)}
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-medium text-slate-300 mb-1.5">
                      Album / Release Name
                    </label>
                    <Input
                      placeholder="e.g. Horizon EP"
                      value={album}
                      onChange={(e) => setAlbum(e.target.value)}
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-medium text-slate-300 mb-1.5">
                      Genre
                    </label>
                    <select
                      value={genre}
                      onChange={(e) => setGenre(e.target.value)}
                      className="w-full h-10 rounded-lg border border-slate-700 bg-slate-900 px-3 text-xs text-slate-200 focus:outline-none focus:border-purple-500"
                    >
                      {GENRE_OPTIONS.map((g) => (
                        <option key={g} value={g}>
                          {g}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1.5">
                    Description / Liner Notes
                  </label>
                  <textarea
                    rows={3}
                    placeholder="Provide production notes, lyrics snippet, or instrumentation details..."
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                    className="w-full rounded-lg border border-slate-700 bg-slate-900 p-2.5 text-xs text-slate-200 placeholder:text-slate-500 focus:outline-none focus:border-purple-500"
                  />
                </div>
              </div>

              <Button
                type="submit"
                className="w-full"
                size="lg"
                isLoading={uploadState === "uploading"}
                disabled={!file}
              >
                <UploadCloud className="h-4 w-4 mr-2" />
                Upload Master Track & Start Transcoding
              </Button>
            </form>
          </CardContent>
        </Card>
      ) : null}
    </div>
  );
}
