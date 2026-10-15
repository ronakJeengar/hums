"use client";

import * as React from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  AlertCircle,
  ArrowLeft,
  CheckCircle2,
  Clock,
  Disc,
  Edit3,
  FileAudio,
  FileCheck,
  FileText,
  Globe,
  HardDrive,
  Headphones,
  Heart,
  ImageIcon,
  Info,
  Layers,
  Lock,
  Play,
  RefreshCw,
  Sliders,
  Sparkles,
  UploadCloud,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { StatusBadge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { api } from "@/lib/api/client";
import { formatDate, formatDuration, formatNumber } from "@/lib/utils";
import { AudioRenditionInfo, CreatorTrackDetail } from "@/types";

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

function CreatorTrackDetailContent() {
  const params = useParams();
  const trackId = params?.id as string;
  const router = useRouter();
  const queryClient = useQueryClient();

  const [activeTab, setActiveTab] = React.useState<
    "overview" | "metadata" | "artwork" | "processing" | "publishing"
  >("overview");

  // Metadata form state
  const [title, setTitle] = React.useState("");
  const [artistName, setArtistName] = React.useState("");
  const [albumName, setAlbumName] = React.useState("");
  const [genre, setGenre] = React.useState("");
  const [description, setDescription] = React.useState("");
  const [metadataSuccess, setMetadataSuccess] = React.useState(false);
  const [metadataError, setMetadataError] = React.useState<string | null>(null);

  // Artwork upload state
  const [artworkFile, setArtworkFile] = React.useState<File | null>(null);
  const [artworkPreview, setArtworkPreview] = React.useState<string | null>(null);
  const [artworkSuccess, setArtworkSuccess] = React.useState(false);
  const [artworkError, setArtworkError] = React.useState<string | null>(null);

  const { data: track, isLoading, error } = useQuery<CreatorTrackDetail>({
    queryKey: ["studio-track-detail", trackId],
    queryFn: () => api.studio.getTrackDetail(trackId),
    enabled: !!trackId,
    refetchInterval: (query) => {
      // Poll every 4 seconds if track is currently processing
      const status = query.state.data?.status;
      return status === "PROCESSING" || status === "UPLOADED" ? 4000 : false;
    },
  });

  // Populate form fields on data load
  React.useEffect(() => {
    if (track) {
      setTitle(track.title || "");
      setArtistName(track.artist_name || "");
      setAlbumName(track.album_name || "");
      setGenre(track.genre || "");
      setDescription(track.description || "");
    }
  }, [track]);

  const updateMetadataMutation = useMutation({
    mutationFn: (data: {
      title: string;
      artist_name?: string;
      album_name?: string;
      genre?: string;
      description?: string;
    }) => api.studio.updateTrack(trackId, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["studio-track-detail", trackId] });
      queryClient.invalidateQueries({ queryKey: ["studio-tracks"] });
      setMetadataSuccess(true);
      setMetadataError(null);
      setTimeout(() => setMetadataSuccess(false), 4000);
    },
    onError: (err: Error) => {
      setMetadataError(err.message || "Failed to update metadata");
      setMetadataSuccess(false);
    },
  });

  const uploadArtworkMutation = useMutation({
    mutationFn: (file: File) => api.studio.uploadTrackArtwork(trackId, file),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["studio-track-detail", trackId] });
      queryClient.invalidateQueries({ queryKey: ["studio-tracks"] });
      setArtworkFile(null);
      setArtworkPreview(null);
      setArtworkSuccess(true);
      setArtworkError(null);
      setTimeout(() => setArtworkSuccess(false), 4000);
    },
    onError: (err: Error) => {
      setArtworkError(err.message || "Artwork upload failed");
      setArtworkSuccess(false);
    },
  });

  const publishingMutation = useMutation({
    mutationFn: (isPublished: boolean) => api.studio.setPublishing(trackId, isPublished),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["studio-track-detail", trackId] });
      queryClient.invalidateQueries({ queryKey: ["studio-tracks"] });
      queryClient.invalidateQueries({ queryKey: ["studio-dashboard"] });
    },
    onError: (err: Error) => {
      alert(`Publishing update failed: ${err.message}`);
    },
  });

  const retryMutation = useMutation({
    mutationFn: () => api.studio.retryTrack(trackId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["studio-track-detail", trackId] });
      queryClient.invalidateQueries({ queryKey: ["studio-tracks"] });
    },
    onError: (err: Error) => {
      alert(`Retry failed: ${err.message}`);
    },
  });

  const handleArtworkChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      if (!file.type.startsWith("image/")) {
        setArtworkError("File must be an image (JPEG, PNG, or WebP).");
        return;
      }
      setArtworkFile(file);
      setArtworkError(null);
      const url = URL.createObjectURL(file);
      setArtworkPreview(url);
    }
  };

  if (isLoading) {
    return (
      <div className="flex h-64 items-center justify-center">
        <div className="flex items-center gap-3 text-sm text-slate-400">
          <RefreshCw className="h-5 w-5 animate-spin text-purple-400" />
          <span>Loading track details & media processing state...</span>
        </div>
      </div>
    );
  }

  if (error || !track) {
    return (
      <div className="p-8 text-center space-y-4">
        <AlertCircle className="h-10 w-10 text-rose-400 mx-auto" />
        <h2 className="text-lg font-bold text-slate-100">Track Not Found</h2>
        <p className="text-xs text-slate-400">
          The requested track does not exist or you do not have permission to manage it.
        </p>
        <Link href="/studio/tracks">
          <Button variant="outline" size="sm">
            <ArrowLeft className="h-4 w-4 mr-1.5" />
            Back to Media Library
          </Button>
        </Link>
      </div>
    );
  }

  const isReady = track.status === "READY";
  const isFailed = track.status === "FAILED";
  const isProcessing = track.status === "PROCESSING" || track.status === "UPLOADED";

  return (
    <div className="space-y-6">
      {/* Back Button & Breadcrumbs */}
      <div className="flex items-center justify-between">
        <Link
          href="/studio/tracks"
          className="inline-flex items-center text-xs text-slate-400 hover:text-slate-200 transition-colors"
        >
          <ArrowLeft className="h-4 w-4 mr-1" />
          Back to Media Library
        </Link>
        <div className="flex items-center gap-2">
          {isFailed && (
            <Button
              variant="outline"
              size="sm"
              onClick={() => retryMutation.mutate()}
              isLoading={retryMutation.isPending}
              className="border-amber-700 bg-amber-950/40 text-amber-300 hover:bg-amber-900/60"
            >
              <RefreshCw className="h-3.5 w-3.5 mr-1.5" />
              Retry Transcode
            </Button>
          )}

          <Button
            variant={track.is_published ? "outline" : "primary"}
            size="sm"
            onClick={() => {
              if (!isReady && !track.is_published) {
                alert("Track must complete media transcoding (READY) before it can be published.");
                return;
              }
              publishingMutation.mutate(!track.is_published);
            }}
            isLoading={publishingMutation.isPending}
            className={
              track.is_published
                ? "border-emerald-700 bg-emerald-950/40 text-emerald-300"
                : ""
            }
          >
            {track.is_published ? (
              <>
                <Globe className="h-3.5 w-3.5 mr-1.5 text-emerald-400" />
                Published (Click to Unpublish)
              </>
            ) : (
              <>
                <Lock className="h-3.5 w-3.5 mr-1.5" />
                Publish Track
              </>
            )}
          </Button>
        </div>
      </div>

      {/* Track Header Card */}
      <div className="p-6 rounded-2xl bg-gradient-to-r from-slate-900 via-slate-900/90 to-purple-950/30 border border-slate-800 flex flex-col md:flex-row items-start md:items-center gap-6">
        <div className="h-28 w-28 rounded-xl bg-slate-800 border border-slate-700 overflow-hidden flex items-center justify-center shrink-0 relative shadow-xl">
          {track.cover_image_key ? (
            <img
              src={`http://127.0.0.1:8001/storage/${track.cover_image_key}`}
              alt={track.title}
              className="h-full w-full object-cover"
            />
          ) : (
            <FileAudio className="h-10 w-10 text-purple-400" />
          )}
        </div>

        <div className="flex-1 min-w-0 space-y-2">
          <div className="flex flex-wrap items-center gap-2">
            <StatusBadge status={track.status} />
            <span
              className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-medium border ${
                track.is_published
                  ? "bg-emerald-950/60 text-emerald-300 border-emerald-800/60"
                  : "bg-slate-800 text-slate-400 border-slate-700"
              }`}
            >
              {track.is_published ? (
                <>
                  <Globe className="h-3 w-3 text-emerald-400" />
                  Public Discovery
                </>
              ) : (
                <>
                  <Lock className="h-3 w-3 text-slate-400" />
                  Private Draft
                </>
              )}
            </span>
            <span className="text-xs text-slate-400">
              Added {formatDate(track.created_at)}
            </span>
          </div>

          <h1 className="text-2xl font-bold text-white tracking-tight truncate">
            {track.title}
          </h1>

          <div className="flex flex-wrap items-center gap-4 text-xs text-slate-300">
            {track.artist_name && (
              <span className="flex items-center gap-1.5">
                <Disc className="h-3.5 w-3.5 text-slate-500" />
                {track.artist_name}
              </span>
            )}
            {track.album_name && (
              <span className="flex items-center gap-1.5">
                <Layers className="h-3.5 w-3.5 text-slate-500" />
                Album: {track.album_name}
              </span>
            )}
            {track.genre && (
              <span className="flex items-center gap-1.5">
                <Sliders className="h-3.5 w-3.5 text-slate-500" />
                {track.genre}
              </span>
            )}
            <span className="flex items-center gap-1.5">
              <Clock className="h-3.5 w-3.5 text-slate-500" />
              {formatDuration(track.duration_seconds)}
            </span>
          </div>
        </div>
      </div>

      {/* Tabs Navigation */}
      <div className="border-b border-slate-800 flex items-center gap-2 overflow-x-auto text-xs font-medium">
        <button
          onClick={() => setActiveTab("overview")}
          className={`pb-3 px-3 transition-colors flex items-center gap-1.5 border-b-2 whitespace-nowrap ${
            activeTab === "overview"
              ? "border-purple-500 text-purple-400 font-semibold"
              : "border-transparent text-slate-400 hover:text-slate-200"
          }`}
        >
          <Info className="h-4 w-4" />
          Overview
        </button>
        <button
          onClick={() => setActiveTab("metadata")}
          className={`pb-3 px-3 transition-colors flex items-center gap-1.5 border-b-2 whitespace-nowrap ${
            activeTab === "metadata"
              ? "border-purple-500 text-purple-400 font-semibold"
              : "border-transparent text-slate-400 hover:text-slate-200"
          }`}
        >
          <FileText className="h-4 w-4" />
          Metadata Editor
        </button>
        <button
          onClick={() => setActiveTab("artwork")}
          className={`pb-3 px-3 transition-colors flex items-center gap-1.5 border-b-2 whitespace-nowrap ${
            activeTab === "artwork"
              ? "border-purple-500 text-purple-400 font-semibold"
              : "border-transparent text-slate-400 hover:text-slate-200"
          }`}
        >
          <ImageIcon className="h-4 w-4" />
          Cover Artwork
        </button>
        <button
          onClick={() => setActiveTab("processing")}
          className={`pb-3 px-3 transition-colors flex items-center gap-1.5 border-b-2 whitespace-nowrap ${
            activeTab === "processing"
              ? "border-purple-500 text-purple-400 font-semibold"
              : "border-transparent text-slate-400 hover:text-slate-200"
          }`}
        >
          <HardDrive className="h-4 w-4" />
          Media Processing & Renditions ({track.renditions?.length || 0})
        </button>
        <button
          onClick={() => setActiveTab("publishing")}
          className={`pb-3 px-3 transition-colors flex items-center gap-1.5 border-b-2 whitespace-nowrap ${
            activeTab === "publishing"
              ? "border-purple-500 text-purple-400 font-semibold"
              : "border-transparent text-slate-400 hover:text-slate-200"
          }`}
        >
          <Globe className="h-4 w-4" />
          Publishing Lifecycle
        </button>
      </div>

      {/* Tab 1: Overview */}
      {activeTab === "overview" && (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="md:col-span-2 space-y-6">
            <Card>
              <CardHeader>
                <CardTitle className="text-base">Playback Preview</CardTitle>
                <CardDescription>
                  Direct audio playback preview for verified owners and creators
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                {isReady && track.renditions && track.renditions.length > 0 ? (
                  <div className="p-4 rounded-xl bg-slate-950/80 border border-slate-800 space-y-3">
                    <div className="flex items-center justify-between text-xs text-slate-400">
                      <span className="font-semibold text-slate-200">
                        Primary Stream Preview ({track.renditions[0].format.toUpperCase()}{" "}
                        {track.renditions[0].bitrate_kbps} kbps)
                      </span>
                      <span>{formatDuration(track.duration_seconds)}</span>
                    </div>
                    <audio
                      controls
                      className="w-full h-10 accent-purple-500"
                      src={`http://127.0.0.1:8001/storage/${track.renditions[0].storage_key}`}
                    >
                      Your browser does not support audio playback.
                    </audio>
                  </div>
                ) : isProcessing ? (
                  <div className="p-6 rounded-xl bg-slate-950/50 border border-slate-800 text-center space-y-2">
                    <RefreshCw className="h-6 w-6 animate-spin text-purple-400 mx-auto" />
                    <p className="text-sm font-medium text-slate-200">
                      Audio Processing in Progress
                    </p>
                    <p className="text-xs text-slate-400">
                      Audio renditions and waveforms are being generated. This page will update automatically.
                    </p>
                  </div>
                ) : (
                  <div className="p-6 rounded-xl bg-rose-950/20 border border-rose-900/40 text-center space-y-2">
                    <AlertCircle className="h-6 w-6 text-rose-400 mx-auto" />
                    <p className="text-sm font-medium text-rose-300">
                      Audio Not Streamable
                    </p>
                    <p className="text-xs text-slate-400">
                      The audio transcoding job failed. Check the Media Processing tab for error details or retry.
                    </p>
                  </div>
                )}

                {track.description && (
                  <div className="pt-2">
                    <h4 className="text-xs font-semibold text-slate-300 mb-1">
                      Track Description / Liner Notes
                    </h4>
                    <p className="text-xs text-slate-400 whitespace-pre-wrap bg-slate-950/40 p-3 rounded-lg border border-slate-800/80">
                      {track.description}
                    </p>
                  </div>
                )}
              </CardContent>
            </Card>
          </div>

          <div className="space-y-6">
            <Card>
              <CardHeader>
                <CardTitle className="text-base">Streaming Performance</CardTitle>
                <CardDescription>Audited playback analytics</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex items-center justify-between p-3 rounded-lg bg-slate-950/60 border border-slate-800/80">
                  <div className="flex items-center gap-2 text-xs text-slate-400">
                    <Headphones className="h-4 w-4 text-purple-400" />
                    <span>Total Streams</span>
                  </div>
                  <span className="font-mono text-sm font-bold text-slate-100">
                    {formatNumber(track.play_count)}
                  </span>
                </div>

                <div className="flex items-center justify-between p-3 rounded-lg bg-slate-950/60 border border-slate-800/80">
                  <div className="flex items-center gap-2 text-xs text-slate-400">
                    <Heart className="h-4 w-4 text-rose-400" />
                    <span>Favorites & Likes</span>
                  </div>
                  <span className="font-mono text-sm font-bold text-slate-100">
                    {formatNumber(track.likes_count)}
                  </span>
                </div>

                <div className="flex items-center justify-between p-3 rounded-lg bg-slate-950/60 border border-slate-800/80">
                  <div className="flex items-center gap-2 text-xs text-slate-400">
                    <Layers className="h-4 w-4 text-sky-400" />
                    <span>Available Renditions</span>
                  </div>
                  <span className="font-mono text-sm font-bold text-slate-100">
                    {track.renditions?.length || 0}
                  </span>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>
      )}

      {/* Tab 2: Metadata Editor */}
      {activeTab === "metadata" && (
        <Card className="max-w-2xl">
          <CardHeader>
            <CardTitle className="text-base">Edit Release Metadata</CardTitle>
            <CardDescription>
              Update public title, album credits, genre classification, and liner notes
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {metadataSuccess && (
              <div className="p-3 rounded-lg bg-emerald-950/50 border border-emerald-800 text-xs text-emerald-300 flex items-center gap-2">
                <CheckCircle2 className="h-4 w-4" />
                Track metadata updated successfully!
              </div>
            )}
            {metadataError && (
              <div className="p-3 rounded-lg bg-rose-950/50 border border-rose-800 text-xs text-rose-300 flex items-center gap-2">
                <AlertCircle className="h-4 w-4" />
                {metadataError}
              </div>
            )}

            <div>
              <label className="text-xs font-medium text-slate-300 block mb-1">
                Track Title *
              </label>
              <Input
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="Track title"
              />
            </div>

            <div>
              <label className="text-xs font-medium text-slate-300 block mb-1">
                Artist Name
              </label>
              <Input
                value={artistName}
                onChange={(e) => setArtistName(e.target.value)}
                placeholder="Artist or ensemble name"
              />
            </div>

            <div>
              <label className="text-xs font-medium text-slate-300 block mb-1">
                Album / EP Name
              </label>
              <Input
                value={albumName}
                onChange={(e) => setAlbumName(e.target.value)}
                placeholder="Album name or leave empty for single"
              />
            </div>

            <div>
              <label className="text-xs font-medium text-slate-300 block mb-1">
                Genre
              </label>
              <select
                value={genre}
                onChange={(e) => setGenre(e.target.value)}
                className="w-full h-10 rounded-lg border border-slate-700 bg-slate-900 px-3 text-sm text-slate-200 focus:outline-none focus:border-purple-500"
              >
                <option value="">Select Genre</option>
                {GENRE_OPTIONS.map((g) => (
                  <option key={g} value={g}>
                    {g}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="text-xs font-medium text-slate-300 block mb-1">
                Description / Liner Notes
              </label>
              <textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                rows={4}
                placeholder="Track description, instruments used, or release notes..."
                className="w-full rounded-lg border border-slate-700 bg-slate-900 p-2.5 text-xs text-slate-200 focus:outline-none focus:border-purple-500"
              />
            </div>

            <Button
              variant="primary"
              onClick={() =>
                updateMetadataMutation.mutate({
                  title,
                  artist_name: artistName || undefined,
                  album_name: albumName || undefined,
                  genre: genre || undefined,
                  description: description || undefined,
                })
              }
              isLoading={updateMetadataMutation.isPending}
            >
              Save Metadata Changes
            </Button>
          </CardContent>
        </Card>
      )}

      {/* Tab 3: Artwork Manager */}
      {activeTab === "artwork" && (
        <Card className="max-w-2xl">
          <CardHeader>
            <CardTitle className="text-base">Cover Artwork</CardTitle>
            <CardDescription>
              Upload or replace high-resolution album cover artwork (JPEG, PNG, or WebP up to 5MB, 200x200 to 4000x4000)
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            {artworkSuccess && (
              <div className="p-3 rounded-lg bg-emerald-950/50 border border-emerald-800 text-xs text-emerald-300 flex items-center gap-2">
                <CheckCircle2 className="h-4 w-4" />
                Cover artwork uploaded successfully!
              </div>
            )}
            {artworkError && (
              <div className="p-3 rounded-lg bg-rose-950/50 border border-rose-800 text-xs text-rose-300 flex items-center gap-2">
                <AlertCircle className="h-4 w-4" />
                {artworkError}
              </div>
            )}

            <div className="flex flex-col sm:flex-row items-center gap-6">
              <div className="h-44 w-44 rounded-xl bg-slate-900 border border-slate-700 overflow-hidden flex items-center justify-center text-slate-500 relative shrink-0 shadow-lg">
                {artworkPreview ? (
                  <img
                    src={artworkPreview}
                    alt="Preview"
                    className="h-full w-full object-cover"
                  />
                ) : track.cover_image_key ? (
                  <img
                    src={`http://127.0.0.1:8001/storage/${track.cover_image_key}`}
                    alt="Current cover"
                    className="h-full w-full object-cover"
                  />
                ) : (
                  <div className="text-center p-4">
                    <ImageIcon className="h-8 w-8 mx-auto text-slate-600 mb-1" />
                    <span className="text-2xs text-slate-500">No artwork assigned</span>
                  </div>
                )}
              </div>

              <div className="flex-1 space-y-3">
                <label className="block">
                  <span className="text-xs font-medium text-slate-300">
                    Select New Image File
                  </span>
                  <input
                    type="file"
                    accept="image/jpeg,image/png,image/webp"
                    onChange={handleArtworkChange}
                    className="mt-1 block w-full text-xs text-slate-400 file:mr-3 file:py-2 file:px-3 file:rounded-lg file:border-0 file:text-xs file:font-semibold file:bg-purple-900/40 file:text-purple-300 hover:file:bg-purple-900/60 cursor-pointer"
                  />
                </label>
                <p className="text-2xs text-slate-500">
                  Recommended: Square aspect ratio (1:1), minimum 1000x1000px for best visual quality on mobile and web player screens.
                </p>

                {artworkFile && (
                  <Button
                    variant="primary"
                    size="sm"
                    onClick={() => uploadArtworkMutation.mutate(artworkFile)}
                    isLoading={uploadArtworkMutation.isPending}
                  >
                    <UploadCloud className="h-4 w-4 mr-1.5" />
                    Upload & Set Artwork
                  </Button>
                )}
              </div>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Tab 4: Media Processing & Renditions */}
      {activeTab === "processing" && (
        <div className="space-y-6">
          {/* Background Jobs Timeline */}
          <Card>
            <CardHeader>
              <CardTitle className="text-base flex items-center justify-between">
                <span>Background Processing Jobs</span>
                {isProcessing && (
                  <span className="inline-flex items-center gap-1.5 text-xs text-purple-400 font-normal">
                    <RefreshCw className="h-3.5 w-3.5 animate-spin" />
                    Live polling active
                  </span>
                )}
              </CardTitle>
              <CardDescription>
                Audited media processing jobs executed by Celery and FFmpeg workers
              </CardDescription>
            </CardHeader>
            <CardContent>
              {track.processing_jobs && track.processing_jobs.length > 0 ? (
                <div className="space-y-3">
                  {track.processing_jobs.map((job) => (
                    <div
                      key={job.id}
                      className="p-4 rounded-xl bg-slate-950/70 border border-slate-800 space-y-2"
                    >
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-2">
                          <StatusBadge status={job.status} />
                          <span className="text-xs font-mono font-medium text-slate-200">
                            {job.job_type}
                          </span>
                        </div>
                        <div className="text-xs text-slate-400">
                          Attempts: <strong className="text-slate-200">{job.attempts}</strong>
                        </div>
                      </div>

                      {job.error_message && (
                        <div className="p-3 rounded-lg bg-rose-950/40 border border-rose-900/60 text-xs text-rose-300 font-mono whitespace-pre-wrap">
                          {job.error_message}
                        </div>
                      )}

                      <div className="text-2xs text-slate-500 flex items-center justify-between pt-1">
                        <span>Created: {formatDate(job.created_at)}</span>
                        <span>Updated: {formatDate(job.updated_at)}</span>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-xs text-slate-500">No background job records found.</p>
              )}
            </CardContent>
          </Card>

          {/* Generated Audio Renditions */}
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Generated Audio Renditions</CardTitle>
              <CardDescription>
                High, Medium, and Data-Saver audio streams encoded for multi-tier streaming
              </CardDescription>
            </CardHeader>
            <CardContent>
              {track.renditions && track.renditions.length > 0 ? (
                <div className="overflow-x-auto">
                  <table className="w-full text-left text-xs text-slate-300">
                    <thead className="bg-slate-950/60 border-b border-slate-800 text-slate-400 uppercase tracking-wider text-2xs">
                      <tr>
                        <th className="px-4 py-2.5">Format</th>
                        <th className="px-4 py-2.5">Codec</th>
                        <th className="px-4 py-2.5">Bitrate</th>
                        <th className="px-4 py-2.5">Sample Rate</th>
                        <th className="px-4 py-2.5">File Size</th>
                        <th className="px-4 py-2.5">Storage Key</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-800/60 font-mono">
                      {track.renditions.map((r) => (
                        <tr key={r.id} className="hover:bg-slate-800/30">
                          <td className="px-4 py-2.5 text-slate-100 uppercase font-bold">
                            {r.format}
                          </td>
                          <td className="px-4 py-2.5 text-slate-300">{r.codec}</td>
                          <td className="px-4 py-2.5 text-purple-300">{r.bitrate_kbps} kbps</td>
                          <td className="px-4 py-2.5 text-slate-400">
                            {r.sample_rate ? `${r.sample_rate} Hz` : "—"}
                          </td>
                          <td className="px-4 py-2.5 text-slate-300">
                            {(r.file_size_bytes / (1024 * 1024)).toFixed(2)} MB
                          </td>
                          <td className="px-4 py-2.5 text-slate-500 text-2xs truncate max-w-xs">
                            {r.storage_key}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              ) : (
                <p className="text-xs text-slate-500">
                  No renditions generated yet. Renditions appear here once background transcoding completes.
                </p>
              )}
            </CardContent>
          </Card>

          {/* Original Uploaded Source File */}
          {track.audio_files && track.audio_files.length > 0 && (
            <Card>
              <CardHeader>
                <CardTitle className="text-base">Master Audio Asset</CardTitle>
                <CardDescription>Original uncompressed audio source file</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-4 text-xs">
                  <div className="p-3 rounded-lg bg-slate-950/60 border border-slate-800">
                    <span className="text-slate-500 block">Filename</span>
                    <span className="font-mono text-slate-200 truncate block mt-0.5">
                      {track.audio_files[0].filename}
                    </span>
                  </div>
                  <div className="p-3 rounded-lg bg-slate-950/60 border border-slate-800">
                    <span className="text-slate-500 block">File Size</span>
                    <span className="font-mono text-slate-200 block mt-0.5">
                      {(track.audio_files[0].file_size_bytes / (1024 * 1024)).toFixed(2)} MB
                    </span>
                  </div>
                  <div className="p-3 rounded-lg bg-slate-950/60 border border-slate-800">
                    <span className="text-slate-500 block">MIME Type</span>
                    <span className="font-mono text-slate-200 block mt-0.5">
                      {track.audio_files[0].mime_type}
                    </span>
                  </div>
                  <div className="p-3 rounded-lg bg-slate-950/60 border border-slate-800">
                    <span className="text-slate-500 block">Uploaded At</span>
                    <span className="text-slate-200 block mt-0.5">
                      {formatDate(track.audio_files[0].created_at)}
                    </span>
                  </div>
                </div>
              </CardContent>
            </Card>
          )}
        </div>
      )}

      {/* Tab 5: Publishing Lifecycle */}
      {activeTab === "publishing" && (
        <Card className="max-w-2xl">
          <CardHeader>
            <CardTitle className="text-base">Publishing & Platform Availability</CardTitle>
            <CardDescription>
              Govern whether this track is publicly discoverable and streamable on Hums
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="p-4 rounded-xl bg-slate-950/70 border border-slate-800 space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h4 className="text-sm font-semibold text-slate-100">
                    Current Platform Status
                  </h4>
                  <p className="text-xs text-slate-400 mt-0.5">
                    {track.is_published
                      ? "Track is currently live and discoverable."
                      : "Track is currently in draft mode and invisible to listeners."}
                  </p>
                </div>
                <span
                  className={`inline-flex items-center gap-1 px-3 py-1 rounded-full text-xs font-bold border ${
                    track.is_published
                      ? "bg-emerald-950/60 text-emerald-300 border-emerald-800/80"
                      : "bg-slate-800 text-slate-400 border-slate-700"
                  }`}
                >
                  {track.is_published ? "PUBLISHED" : "DRAFT"}
                </span>
              </div>

              <div className="border-t border-slate-800/80 pt-4 space-y-2 text-xs text-slate-300">
                <h5 className="font-semibold text-slate-200">Readiness Criteria:</h5>
                <div className="flex items-center gap-2">
                  {isReady ? (
                    <CheckCircle2 className="h-4 w-4 text-emerald-400" />
                  ) : (
                    <AlertCircle className="h-4 w-4 text-rose-400" />
                  )}
                  <span>
                    Transcoding Status: <strong>{track.status}</strong>{" "}
                    {isReady ? "(Ready for streaming)" : "(Must be READY to publish)"}
                  </span>
                </div>
                <div className="flex items-center gap-2">
                  <CheckCircle2 className="h-4 w-4 text-emerald-400" />
                  <span>
                    Audio Renditions Generated: <strong>{track.renditions?.length || 0}</strong>
                  </span>
                </div>
              </div>
            </div>

            <div className="flex items-center gap-3">
              <Button
                variant={track.is_published ? "outline" : "primary"}
                onClick={() => {
                  if (!isReady && !track.is_published) {
                    alert("Track must be in READY state before it can be published.");
                    return;
                  }
                  publishingMutation.mutate(!track.is_published);
                }}
                isLoading={publishingMutation.isPending}
              >
                {track.is_published ? (
                  <>
                    <Lock className="h-4 w-4 mr-1.5" />
                    Unpublish Track (Move to Draft)
                  </>
                ) : (
                  <>
                    <Globe className="h-4 w-4 mr-1.5" />
                    Publish Track to Platform
                  </>
                )}
              </Button>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}

export default function CreatorTrackDetailPage() {
  return (
    <React.Suspense
      fallback={
        <div className="flex flex-col items-center justify-center min-h-[450px] space-y-4">
          <RefreshCw className="h-8 w-8 text-purple-400 animate-spin" />
          <p className="text-sm text-slate-400">Loading track details...</p>
        </div>
      }
    >
      <CreatorTrackDetailContent />
    </React.Suspense>
  );
}
