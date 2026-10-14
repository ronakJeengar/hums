"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { ArrowLeft, CheckCircle2, UploadCloud } from "lucide-react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent } from "@/components/ui/card";

export default function CreatorUploadPage() {
  const router = useRouter();

  const [file, setFile] = React.useState<File | null>(null);
  const [title, setTitle] = React.useState("");
  const [album, setAlbum] = React.useState("");
  const [genre, setGenre] = React.useState("Electronic");
  const [description, setDescription] = React.useState("");
  const [isUploading, setIsUploading] = React.useState(false);
  const [uploadProgress, setUploadProgress] = React.useState<string | null>(null);
  const [errorMessage, setErrorMessage] = React.useState<string | null>(null);

  const fileInputRef = React.useRef<HTMLInputElement>(null);

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      const selected = e.target.files[0];
      setFile(selected);
      if (!title) {
        // Auto-fill title from filename without extension
        const base = selected.name.replace(/\.[^/.]+$/, "");
        setTitle(base);
      }
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!file) {
      setErrorMessage("Please select an audio file to upload.");
      return;
    }
    if (!title) {
      setErrorMessage("Track title is required.");
      return;
    }

    setIsUploading(true);
    setErrorMessage(null);
    setUploadProgress("Uploading master audio to secure storage...");

    try {
      const formData = new FormData();
      formData.append("file", file);
      formData.append("title", title);
      if (album) formData.append("album", album);
      if (genre) formData.append("genre", genre);
      if (description) formData.append("description", description);

      const res = await fetch("/api/proxy/audio/upload", {
        method: "POST",
        body: formData,
      });

      const data = await res.json();
      if (!res.ok || !data.success) {
        throw new Error(data?.error?.message || data?.detail || "Audio upload failed");
      }

      setUploadProgress("Upload successful! Queued transcoding job.");
      setTimeout(() => {
        router.push("/studio/tracks");
      }, 1200);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Failed to upload audio.";
      setErrorMessage(msg);
      setIsUploading(false);
      setUploadProgress(null);
    }
  };

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      <div className="flex items-center gap-3">
        <Link href="/studio/tracks">
          <Button variant="ghost" size="sm">
            <ArrowLeft className="h-4 w-4 mr-1" />
            Back to Tracks
          </Button>
        </Link>
      </div>

      <div>
        <h1 className="text-xl font-bold tracking-tight text-white">
          Upload New Master Audio
        </h1>
        <p className="text-xs text-slate-400 mt-1">
          Master tracks will automatically be transcoded into high-fidelity streaming renditions
        </p>
      </div>

      <Card>
        <CardContent className="pt-6">
          {errorMessage && (
            <div className="mb-6 p-3 rounded-lg bg-rose-950/50 border border-rose-800 text-xs text-rose-300">
              {errorMessage}
            </div>
          )}

          {uploadProgress && (
            <div className="mb-6 p-3 rounded-lg bg-purple-950/50 border border-purple-800 text-xs text-purple-300 flex items-center gap-2">
              <CheckCircle2 className="h-4 w-4 text-purple-400 shrink-0" />
              <span>{uploadProgress}</span>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-5">
            {/* Dropzone */}
            <div
              onClick={() => fileInputRef.current?.click()}
              className="border-2 border-dashed border-slate-700 hover:border-purple-500 rounded-xl p-8 text-center cursor-pointer bg-slate-950/40 hover:bg-slate-900/40 transition-colors"
            >
              <input
                ref={fileInputRef}
                type="file"
                accept="audio/*"
                className="hidden"
                onChange={handleFileChange}
              />
              <div className="flex flex-col items-center justify-center gap-2">
                <div className="h-12 w-12 rounded-full bg-purple-950/60 border border-purple-800/60 flex items-center justify-center text-purple-400">
                  <UploadCloud className="h-6 w-6" />
                </div>
                {file ? (
                  <div>
                    <span className="font-semibold text-sm text-purple-300 block">
                      {file.name}
                    </span>
                    <span className="text-xs text-slate-500">
                      {(file.size / (1024 * 1024)).toFixed(2)} MB • Ready to upload
                    </span>
                  </div>
                ) : (
                  <div>
                    <span className="font-semibold text-sm text-slate-200 block">
                      Choose master audio file or drag & drop here
                    </span>
                    <span className="text-xs text-slate-500">
                      Supports FLAC, WAV, MP3, AAC, OGG up to 250MB
                    </span>
                  </div>
                )}
              </div>
            </div>

            {/* Metadata Fields */}
            <div>
              <label className="block text-xs font-medium text-slate-300 mb-1.5">
                Track Title *
              </label>
              <Input
                placeholder="e.g. Midnight Reverie"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                required
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1.5">
                  Album / Release Name
                </label>
                <Input
                  placeholder="e.g. Echoes in Neon"
                  value={album}
                  onChange={(e) => setAlbum(e.target.value)}
                />
              </div>

              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1.5">
                  Primary Genre
                </label>
                <Input
                  placeholder="e.g. Synthwave, Ambient, Indie"
                  value={genre}
                  onChange={(e) => setGenre(e.target.value)}
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-medium text-slate-300 mb-1.5">
                Description / Liner Notes
              </label>
              <textarea
                rows={3}
                placeholder="Add credits, production notes, or instruments..."
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                className="w-full rounded-lg border border-slate-700 bg-slate-900 p-2.5 text-xs text-slate-200 placeholder:text-slate-500 focus:outline-none focus:border-purple-500"
              />
            </div>

            <Button
              type="submit"
              className="w-full"
              size="lg"
              isLoading={isUploading}
              disabled={!file}
            >
              Upload Master Track & Start Transcoding
            </Button>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
