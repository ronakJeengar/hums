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
  FileAudio,
  FileCheck,
  Globe,
  HardDrive,
  Headphones,
  Heart,
  History,
  ImageIcon,
  Info,
  Layers,
  Lock,
  Play,
  RefreshCw,
  Shield,
  ShieldAlert,
  ShieldCheck,
  UploadCloud,
  User,
  UserCheck,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { StatusBadge, Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { api } from "@/lib/api/client";
import { formatDate, formatDuration, formatNumber } from "@/lib/utils";
import { AdminTrackDetail, AudioRenditionInfo, ProcessingJobInfo, AdminAuditLog } from "@/types";

function AdminTrackDetailContent() {
  const params = useParams();
  const trackId = params?.id as string;
  const router = useRouter();
  const queryClient = useQueryClient();

  const [activeTab, setActiveTab] = React.useState<
    "overview" | "metadata" | "processing" | "moderation" | "audit"
  >("overview");

  // Moderation form state
  const [selectedStatusOverride, setSelectedStatusOverride] = React.useState<"READY" | "MODERATED" | "FAILED" | null>(null);
  const [moderationReason, setModerationReason] = React.useState("");
  const [moderationSuccess, setModerationSuccess] = React.useState(false);
  const [moderationError, setModerationError] = React.useState<string | null>(null);

  // Artwork upload state
  const [artworkFile, setArtworkFile] = React.useState<File | null>(null);
  const [artworkPreview, setArtworkPreview] = React.useState<string | null>(null);
  const [artworkSuccess, setArtworkSuccess] = React.useState(false);
  const [artworkError, setArtworkError] = React.useState<string | null>(null);

  const { data: track, isLoading, error } = useQuery<AdminTrackDetail>({
    queryKey: ["admin-track-detail", trackId],
    queryFn: () => api.admin.getTrackDetail(trackId),
    enabled: !!trackId,
    refetchInterval: (query) => {
      const status = query.state.data?.status;
      return status === "PROCESSING" || status === "UPLOADED" ? 4000 : false;
    },
  });

  const targetStatus: "READY" | "MODERATED" | "FAILED" =
    selectedStatusOverride ?? (track?.status === "MODERATED" ? "READY" : "MODERATED");
  const setTargetStatus = (status: "READY" | "MODERATED" | "FAILED") => setSelectedStatusOverride(status);

  const moderateMutation = useMutation({
    mutationFn: ({ status, reason }: { status: "READY" | "MODERATED" | "FAILED"; reason: string }) =>
      api.admin.moderateTrack(trackId, status, reason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-track-detail", trackId] });
      queryClient.invalidateQueries({ queryKey: ["admin-tracks"] });
      setModerationSuccess(true);
      setModerationError(null);
      setModerationReason("");
      setTimeout(() => setModerationSuccess(false), 5000);
    },
    onError: (err: Error) => {
      setModerationError(err.message || "Failed to moderate track");
      setModerationSuccess(false);
    },
  });

  const retryMutation = useMutation({
    mutationFn: () => api.admin.retryTrack(trackId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-track-detail", trackId] });
      queryClient.invalidateQueries({ queryKey: ["admin-tracks"] });
    },
  });

  const uploadArtworkMutation = useMutation({
    mutationFn: (file: File) => api.admin.uploadTrackArtwork(trackId, file),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-track-detail", trackId] });
      queryClient.invalidateQueries({ queryKey: ["admin-tracks"] });
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

  const togglePublishingMutation = useMutation({
    mutationFn: (publish: boolean) =>
      api.admin.bulkAction({
        action: publish ? "publish" : "unpublish",
        track_ids: [trackId],
        reason: publish ? "Published by administrator" : "Unpublished by administrator",
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-track-detail", trackId] });
      queryClient.invalidateQueries({ queryKey: ["admin-tracks"] });
    },
  });

  const handleArtworkFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      if (!file.type.startsWith("image/")) {
        setArtworkError("Please select a valid image file (JPEG, PNG, WebP)");
        return;
      }
      setArtworkFile(file);
      const url = URL.createObjectURL(file);
      setArtworkPreview(url);
      setArtworkError(null);
    }
  };

  if (isLoading) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[450px] space-y-4">
        <RefreshCw className="h-8 w-8 text-purple-400 animate-spin" />
        <p className="text-sm text-slate-400">Loading catalog track detail...</p>
      </div>
    );
  }

  if (error || !track) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[450px] space-y-4">
        <AlertCircle className="h-10 w-10 text-rose-400" />
        <h2 className="text-lg font-semibold text-white">Track Not Found</h2>
        <p className="text-xs text-slate-400">
          The requested track could not be loaded or may not exist.
        </p>
        <Link href="/admin/tracks">
          <Button variant="outline" size="sm">
            <ArrowLeft className="h-4 w-4 mr-2" />
            Back to Tracks Catalog
          </Button>
        </Link>
      </div>
    );
  }

  return (
    <div className="space-y-6 max-w-7xl pb-24">
      {/* Navigation & Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <Link href="/admin/tracks">
            <Button variant="ghost" size="sm" className="h-9 w-9 p-0 text-slate-400 hover:text-white">
              <ArrowLeft className="h-4 w-4" />
            </Button>
          </Link>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-xl font-bold tracking-tight text-white">{track.title}</h1>
              <StatusBadge status={track.status} />
              <Badge
                variant={track.is_published ? "success" : "default"}
                className="text-[10px] font-semibold gap-1"
              >
                {track.is_published ? <Globe className="h-2.5 w-2.5" /> : <Lock className="h-2.5 w-2.5" />}
                {track.is_published ? "Published" : "Draft / Private"}
              </Badge>
            </div>
            <p className="text-xs text-slate-400 mt-0.5">
              by <span className="text-slate-200">{track.artist_name || "Unknown Artist"}</span>
              {track.album_name ? ` • Album: ${track.album_name}` : ""}
              <span className="font-mono text-slate-500 ml-2">ID: {track.id}</span>
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 self-start sm:self-auto">
          {track.status === "FAILED" && (
            <Button
              variant="outline"
              size="sm"
              onClick={() => retryMutation.mutate()}
              isLoading={retryMutation.isPending}
              className="text-amber-400 border-amber-500/30 hover:bg-amber-500/10"
            >
              <RefreshCw className="h-3.5 w-3.5 mr-1.5" />
              Retry Transcoding
            </Button>
          )}

          <Button
            variant={track.status === "MODERATED" ? "primary" : "danger"}
            size="sm"
            onClick={() => setActiveTab("moderation")}
            className="text-xs"
          >
            <ShieldAlert className="h-3.5 w-3.5 mr-1.5" />
            {track.status === "MODERATED" ? "Restore Track" : "Moderate / Takedown"}
          </Button>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex items-center gap-1 border-b border-slate-800 pb-px overflow-x-auto">
        <button
          onClick={() => setActiveTab("overview")}
          className={`flex items-center gap-2 px-4 py-2.5 text-xs font-medium border-b-2 transition-colors whitespace-nowrap ${
            activeTab === "overview"
              ? "border-purple-500 text-purple-400"
              : "border-transparent text-slate-400 hover:text-slate-200"
          }`}
        >
          <Info className="h-3.5 w-3.5" />
          Overview & Ownership
        </button>
        <button
          onClick={() => setActiveTab("metadata")}
          className={`flex items-center gap-2 px-4 py-2.5 text-xs font-medium border-b-2 transition-colors whitespace-nowrap ${
            activeTab === "metadata"
              ? "border-purple-500 text-purple-400"
              : "border-transparent text-slate-400 hover:text-slate-200"
          }`}
        >
          <Disc className="h-3.5 w-3.5" />
          Metadata & Artwork
        </button>
        <button
          onClick={() => setActiveTab("processing")}
          className={`flex items-center gap-2 px-4 py-2.5 text-xs font-medium border-b-2 transition-colors whitespace-nowrap ${
            activeTab === "processing"
              ? "border-purple-500 text-purple-400"
              : "border-transparent text-slate-400 hover:text-slate-200"
          }`}
        >
          <Layers className="h-3.5 w-3.5" />
          Media Processing & Renditions ({track.renditions?.length ?? 0})
        </button>
        <button
          onClick={() => setActiveTab("moderation")}
          className={`flex items-center gap-2 px-4 py-2.5 text-xs font-medium border-b-2 transition-colors whitespace-nowrap ${
            activeTab === "moderation"
              ? "border-purple-500 text-purple-400"
              : "border-transparent text-slate-400 hover:text-slate-200"
          }`}
        >
          <ShieldAlert className="h-3.5 w-3.5" />
          Moderation Controls
        </button>
        <button
          onClick={() => setActiveTab("audit")}
          className={`flex items-center gap-2 px-4 py-2.5 text-xs font-medium border-b-2 transition-colors whitespace-nowrap ${
            activeTab === "audit"
              ? "border-purple-500 text-purple-400"
              : "border-transparent text-slate-400 hover:text-slate-200"
          }`}
        >
          <History className="h-3.5 w-3.5" />
          Track Audit Log ({track.audit_logs?.length ?? 0})
        </button>
      </div>

      {/* TAB 1: OVERVIEW & OWNERSHIP */}
      {activeTab === "overview" && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Left Column: Player & Stats */}
          <div className="lg:col-span-2 space-y-6">
            <Card className="border-slate-800 bg-slate-900/60 backdrop-blur">
              <CardHeader className="pb-3">
                <CardTitle className="text-sm font-semibold text-slate-200 flex items-center gap-2">
                  <Play className="h-4 w-4 text-purple-400" />
                  Media Stream Preview
                </CardTitle>
                <CardDescription className="text-xs text-slate-400">
                  Direct inspection of authorized streaming endpoint
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex flex-col sm:flex-row items-center gap-4 p-4 rounded-xl bg-slate-950 border border-slate-800/80">
                  <div className="h-20 w-20 rounded-lg bg-slate-800 border border-slate-700/60 overflow-hidden flex items-center justify-center text-slate-400 shrink-0">
                    {track.cover_image_key ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={`http://127.0.0.1:8001/api/v1/audio/tracks/${track.id}/artwork?thumb=1`}
                        alt=""
                        className="h-full w-full object-cover"
                      />
                    ) : (
                      <FileAudio className="h-8 w-8 text-slate-500" />
                    )}
                  </div>
                  <div className="w-full space-y-2">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-medium text-slate-200">{track.title}</span>
                      <span className="text-xs text-slate-400">
                        {formatDuration(track.duration_seconds)}
                      </span>
                    </div>
                    {track.status === "READY" ? (
                      <audio
                        controls
                        className="w-full h-9 rounded"
                        src={`http://127.0.0.1:8001/api/v1/audio/tracks/${track.id}/stream`}
                      >
                        Your browser does not support the audio element.
                      </audio>
                    ) : (
                      <div className="p-2.5 rounded-lg bg-slate-900 border border-slate-800 text-xs text-slate-400 flex items-center gap-2">
                        <AlertCircle className="h-4 w-4 text-amber-400 shrink-0" />
                        <span>
                          Preview is unavailable because track status is <strong>{track.status}</strong>.
                        </span>
                      </div>
                    )}
                  </div>
                </div>

                <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                  <div className="p-3 rounded-lg bg-slate-950/60 border border-slate-800">
                    <div className="flex items-center gap-1.5 text-slate-400 text-xs">
                      <Headphones className="h-3.5 w-3.5 text-purple-400" />
                      <span>Total Streams</span>
                    </div>
                    <div className="text-lg font-bold text-slate-100 mt-1">
                      {formatNumber(track.play_count)}
                    </div>
                  </div>
                  <div className="p-3 rounded-lg bg-slate-950/60 border border-slate-800">
                    <div className="flex items-center gap-1.5 text-slate-400 text-xs">
                      <Heart className="h-3.5 w-3.5 text-rose-400" />
                      <span>Favorites / Likes</span>
                    </div>
                    <div className="text-lg font-bold text-slate-100 mt-1">
                      {formatNumber(track.likes_count)}
                    </div>
                  </div>
                  <div className="p-3 rounded-lg bg-slate-950/60 border border-slate-800">
                    <div className="flex items-center gap-1.5 text-slate-400 text-xs">
                      <Clock className="h-3.5 w-3.5 text-cyan-400" />
                      <span>Duration</span>
                    </div>
                    <div className="text-lg font-bold text-slate-100 mt-1">
                      {formatDuration(track.duration_seconds)}
                    </div>
                  </div>
                  <div className="p-3 rounded-lg bg-slate-950/60 border border-slate-800">
                    <div className="flex items-center gap-1.5 text-slate-400 text-xs">
                      <HardDrive className="h-3.5 w-3.5 text-emerald-400" />
                      <span>Renditions</span>
                    </div>
                    <div className="text-lg font-bold text-slate-100 mt-1">
                      {track.renditions?.length ?? 0}
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Description & Track Notes */}
            <Card className="border-slate-800 bg-slate-900/60 backdrop-blur">
              <CardHeader className="pb-3">
                <CardTitle className="text-sm font-semibold text-slate-200">
                  Track Description & Bio
                </CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-xs text-slate-300 leading-relaxed whitespace-pre-wrap">
                  {track.description || "No description provided by creator."}
                </p>
              </CardContent>
            </Card>
          </div>

          {/* Right Column: Ownership & Status Controls */}
          <div className="space-y-6">
            <Card className="border-slate-800 bg-slate-900/60 backdrop-blur">
              <CardHeader className="pb-3">
                <CardTitle className="text-sm font-semibold text-slate-200 flex items-center gap-2">
                  <UserCheck className="h-4 w-4 text-purple-400" />
                  Creator Ownership
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-3 text-xs">
                {track.creator && (
                  <div className="p-3 rounded-lg bg-slate-950 border border-slate-800 space-y-1.5">
                    <div className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider">
                      Creator Profile
                    </div>
                    <div className="font-semibold text-slate-100 flex items-center gap-1.5">
                      {track.creator.name}
                      {track.creator.is_verified && (
                        <CheckCircle2 className="h-3.5 w-3.5 text-purple-400" />
                      )}
                    </div>
                    <div className="text-[11px] text-slate-500 font-mono">
                      Creator ID: {track.creator.id}
                    </div>
                  </div>
                )}

                {track.owner && (
                  <div className="p-3 rounded-lg bg-slate-950 border border-slate-800 space-y-1.5">
                    <div className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider">
                      Underlying User Account
                    </div>
                    <div className="font-medium text-slate-200">
                      {track.owner.name || "No Display Name"}
                    </div>
                    <div className="text-slate-400">{track.owner.email}</div>
                    <div className="flex items-center gap-2 pt-1">
                      <Badge variant="outline" className="text-[10px]">
                        Role: {track.owner.role}
                      </Badge>
                      <Badge
                        variant={track.owner.is_active ? "success" : "danger"}
                        className="text-[10px]"
                      >
                        {track.owner.is_active ? "Active" : "Disabled"}
                      </Badge>
                    </div>
                    <div className="text-[11px] text-slate-500 font-mono pt-1">
                      User ID: {track.owner.id}
                    </div>
                  </div>
                )}

                <div className="pt-2 border-t border-slate-800 space-y-1.5">
                  <div className="flex justify-between text-slate-400">
                    <span>Uploaded on:</span>
                    <span className="text-slate-200">{formatDate(track.created_at)}</span>
                  </div>
                  <div className="flex justify-between text-slate-400">
                    <span>Genre:</span>
                    <span className="text-slate-200">{track.genre || "Uncategorized"}</span>
                  </div>
                  <div className="flex justify-between text-slate-400">
                    <span>Waveform:</span>
                    <span className="text-slate-200">
                      {track.waveform_key ? "Generated" : "None"}
                    </span>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Quick Administrative Overrides */}
            <Card className="border-slate-800 bg-slate-900/60 backdrop-blur">
              <CardHeader className="pb-3">
                <CardTitle className="text-sm font-semibold text-slate-200 flex items-center gap-2">
                  <ShieldCheck className="h-4 w-4 text-purple-400" />
                  Publishing State Override
                </CardTitle>
                <CardDescription className="text-xs text-slate-400">
                  Override creator publishing visibility
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-3">
                <div className="p-3 rounded-lg bg-slate-950 border border-slate-800 flex items-center justify-between">
                  <div className="text-xs">
                    <div className="font-medium text-slate-200">Public Streaming State</div>
                    <div className="text-[11px] text-slate-400">
                      {track.is_published ? "Visible in public search" : "Hidden from listeners"}
                    </div>
                  </div>
                  <Button
                    variant={track.is_published ? "outline" : "primary"}
                    size="sm"
                    onClick={() => togglePublishingMutation.mutate(!track.is_published)}
                    isLoading={togglePublishingMutation.isPending}
                    className="text-xs"
                  >
                    {track.is_published ? "Force Unpublish" : "Force Publish"}
                  </Button>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>
      )}

      {/* TAB 2: METADATA & ARTWORK */}
      {activeTab === "metadata" && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Metadata Display */}
          <Card className="border-slate-800 bg-slate-900/60 backdrop-blur">
            <CardHeader>
              <CardTitle className="text-sm font-semibold text-slate-200">
                Authoritative Track Metadata
              </CardTitle>
              <CardDescription className="text-xs text-slate-400">
                Metadata provided during upload or updated by creator
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4 text-xs">
              <div>
                <label className="text-slate-400 block mb-1">Track Title</label>
                <div className="p-2.5 rounded-lg bg-slate-950 border border-slate-800 text-slate-100 font-medium">
                  {track.title}
                </div>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-slate-400 block mb-1">Artist Name</label>
                  <div className="p-2.5 rounded-lg bg-slate-950 border border-slate-800 text-slate-100">
                    {track.artist_name || "—"}
                  </div>
                </div>
                <div>
                  <label className="text-slate-400 block mb-1">Album / Release</label>
                  <div className="p-2.5 rounded-lg bg-slate-950 border border-slate-800 text-slate-100">
                    {track.album_name || "—"}
                  </div>
                </div>
              </div>
              <div>
                <label className="text-slate-400 block mb-1">Genre Category</label>
                <div className="p-2.5 rounded-lg bg-slate-950 border border-slate-800 text-slate-100">
                  {track.genre || "—"}
                </div>
              </div>
              <div>
                <label className="text-slate-400 block mb-1">Description / Notes</label>
                <div className="p-2.5 rounded-lg bg-slate-950 border border-slate-800 text-slate-100 min-h-[80px] whitespace-pre-wrap">
                  {track.description || "No description provided."}
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Artwork Inspection & Replacement */}
          <Card className="border-slate-800 bg-slate-900/60 backdrop-blur">
            <CardHeader>
              <CardTitle className="text-sm font-semibold text-slate-200 flex items-center gap-2">
                <ImageIcon className="h-4 w-4 text-purple-400" />
                Artwork Asset
              </CardTitle>
              <CardDescription className="text-xs text-slate-400">
                High-resolution cover image in MinIO object storage
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              {artworkSuccess && (
                <div className="p-3 rounded-lg bg-emerald-950/60 border border-emerald-800 text-xs text-emerald-300 flex items-center gap-2">
                  <CheckCircle2 className="h-4 w-4 shrink-0" />
                  <span>Artwork replaced successfully!</span>
                </div>
              )}

              {artworkError && (
                <div className="p-3 rounded-lg bg-rose-950/60 border border-rose-800 text-xs text-rose-300 flex items-center gap-2">
                  <AlertCircle className="h-4 w-4 shrink-0" />
                  <span>{artworkError}</span>
                </div>
              )}

              <div className="flex flex-col sm:flex-row items-center gap-4">
                <div className="h-36 w-36 rounded-xl bg-slate-950 border border-slate-800 overflow-hidden flex items-center justify-center shrink-0">
                  {artworkPreview ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={artworkPreview} alt="New Preview" className="h-full w-full object-cover" />
                  ) : track.cover_image_key ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={`http://127.0.0.1:8001/api/v1/audio/tracks/${track.id}/artwork?thumb=1`}
                      alt="Current Cover"
                      className="h-full w-full object-cover"
                    />
                  ) : (
                    <FileAudio className="h-12 w-12 text-slate-600" />
                  )}
                </div>

                <div className="space-y-2 text-xs">
                  <div className="text-slate-300 font-medium">Cover Image Details</div>
                  <div className="text-slate-500 font-mono text-[11px] break-all">
                    Key: {track.cover_image_key || "No cover image attached"}
                  </div>

                  <div className="pt-2">
                    <label className="inline-flex items-center gap-2 px-3 py-1.5 rounded-lg border border-slate-700 bg-slate-800 hover:bg-slate-700 text-slate-200 cursor-pointer text-xs transition-colors">
                      <UploadCloud className="h-3.5 w-3.5" />
                      <span>Select New Cover File</span>
                      <input
                        type="file"
                        accept="image/jpeg,image/png,image/webp"
                        className="hidden"
                        onChange={handleArtworkFileChange}
                      />
                    </label>
                  </div>
                </div>
              </div>

              {artworkFile && (
                <div className="flex items-center gap-2 pt-2">
                  <Button
                    variant="primary"
                    size="sm"
                    onClick={() => uploadArtworkMutation.mutate(artworkFile)}
                    isLoading={uploadArtworkMutation.isPending}
                    className="text-xs"
                  >
                    Upload & Replace Artwork
                  </Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => {
                      setArtworkFile(null);
                      setArtworkPreview(null);
                    }}
                    className="text-xs"
                  >
                    Cancel
                  </Button>
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      )}

      {/* TAB 3: MEDIA PROCESSING & RENDITIONS */}
      {activeTab === "processing" && (
        <div className="space-y-6">
          {/* Audio Renditions Table */}
          <Card className="border-slate-800 bg-slate-900/60 backdrop-blur">
            <CardHeader className="pb-3">
              <CardTitle className="text-sm font-semibold text-slate-200 flex items-center justify-between">
                <span className="flex items-center gap-2">
                  <Disc className="h-4 w-4 text-purple-400" />
                  Transcoded Audio Renditions
                </span>
                <span className="text-xs font-normal text-slate-400">
                  {track.renditions?.length ?? 0} variants available
                </span>
              </CardTitle>
              <CardDescription className="text-xs text-slate-400">
                Multi-bitrate AAC and MP3 renditions produced by FFmpeg Celery worker
              </CardDescription>
            </CardHeader>
            <CardContent>
              {track.renditions && track.renditions.length > 0 ? (
                <div className="overflow-x-auto">
                  <table className="w-full text-left text-xs">
                    <thead>
                      <tr className="border-b border-slate-800 text-slate-400">
                        <th className="pb-2.5 font-medium">Quality Profile</th>
                        <th className="pb-2.5 font-medium">Format</th>
                        <th className="pb-2.5 font-medium">Bitrate</th>
                        <th className="pb-2.5 font-medium">Sample Rate</th>
                        <th className="pb-2.5 font-medium">Channels</th>
                        <th className="pb-2.5 font-medium">File Size</th>
                        <th className="pb-2.5 font-medium">Storage Key</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-800/60">
                      {track.renditions.map((r: AudioRenditionInfo) => (
                        <tr key={r.id} className="text-slate-300 hover:bg-slate-800/20">
                          <td className="py-2.5 font-semibold text-slate-100 flex items-center gap-1.5">
                            <span className="h-2 w-2 rounded-full bg-purple-400" />
                            {r.bitrate_kbps} kbps ({r.codec.toUpperCase()})
                          </td>
                          <td className="py-2.5 uppercase font-mono text-[11px]">{r.format}</td>
                          <td className="py-2.5 font-mono text-[11px]">{r.bitrate_kbps} kbps</td>
                          <td className="py-2.5 font-mono text-[11px]">
                            {r.sample_rate ? `${r.sample_rate / 1000} kHz` : "—"}
                          </td>
                          <td className="py-2.5">{r.channels === 2 ? "Stereo" : "Mono"}</td>
                          <td className="py-2.5 font-mono text-[11px]">
                            {(r.file_size_bytes / (1024 * 1024)).toFixed(2)} MB
                          </td>
                          <td className="py-2.5 font-mono text-[10px] text-slate-500 max-w-[160px] truncate">
                            {r.storage_key}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              ) : (
                <div className="text-center py-8 text-xs text-slate-400">
                  <AlertCircle className="h-6 w-6 text-amber-400 mx-auto mb-2" />
                  No transcoded renditions available yet. Track status is{" "}
                  <strong>{track.status}</strong>.
                </div>
              )}
            </CardContent>
          </Card>

          {/* Celery Processing Jobs */}
          <Card className="border-slate-800 bg-slate-900/60 backdrop-blur">
            <CardHeader className="pb-3">
              <CardTitle className="text-sm font-semibold text-slate-200 flex items-center justify-between">
                <span className="flex items-center gap-2">
                  <Layers className="h-4 w-4 text-purple-400" />
                  Background Transcoding Pipeline Jobs
                </span>
                {track.status === "FAILED" && (
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => retryMutation.mutate()}
                    isLoading={retryMutation.isPending}
                    className="text-xs text-amber-400 border-amber-500/30"
                  >
                    <RefreshCw className="h-3 w-3 mr-1" />
                    Retry Transcoding
                  </Button>
                )}
              </CardTitle>
              <CardDescription className="text-xs text-slate-400">
                Detailed execution logs and retry attempts recorded by the asynchronous worker
              </CardDescription>
            </CardHeader>
            <CardContent>
              {track.processing_jobs && track.processing_jobs.length > 0 ? (
                <div className="space-y-3">
                  {track.processing_jobs.map((job: ProcessingJobInfo) => (
                    <div
                      key={job.id}
                      className="p-3.5 rounded-lg border border-slate-800 bg-slate-950 space-y-2 text-xs"
                    >
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-2">
                          <span className="font-semibold text-slate-200 font-mono">
                            {job.job_type}
                          </span>
                          <StatusBadge status={job.status} />
                        </div>
                        <div className="text-slate-400 text-[11px]">
                          Attempts: <strong className="text-slate-200">{job.attempts}</strong>
                        </div>
                      </div>

                      {job.error_message && (
                        <div className="p-2.5 rounded bg-rose-950/50 border border-rose-900 text-rose-300 font-mono text-[11px] whitespace-pre-wrap break-all">
                          {job.error_message}
                        </div>
                      )}

                      <div className="flex items-center justify-between text-[11px] text-slate-500 pt-1 border-t border-slate-900">
                        <span>Created: {formatDate(job.created_at)}</span>
                        <span>Updated: {formatDate(job.updated_at)}</span>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-center py-6 text-xs text-slate-400">
                  No individual processing jobs logged.
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      )}

      {/* TAB 4: MODERATION CONTROLS */}
      {activeTab === "moderation" && (
        <div className="max-w-2xl space-y-6">
          <Card className="border-slate-800 bg-slate-900/60 backdrop-blur">
            <CardHeader>
              <CardTitle className="text-sm font-semibold text-slate-200 flex items-center gap-2">
                <ShieldAlert className="h-4 w-4 text-purple-400" />
                Administrative Content Moderation
              </CardTitle>
              <CardDescription className="text-xs text-slate-400">
                Execute takedowns, flag policy or copyright infringements, or restore clean content.
                Every moderation change is recorded in the permanent audit trail.
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              {moderationSuccess && (
                <div className="p-3 rounded-lg bg-emerald-950/60 border border-emerald-800 text-xs text-emerald-300 flex items-center gap-2">
                  <CheckCircle2 className="h-4 w-4 shrink-0" />
                  <span>Content moderation action executed successfully!</span>
                </div>
              )}

              {moderationError && (
                <div className="p-3 rounded-lg bg-rose-950/60 border border-rose-800 text-xs text-rose-300 flex items-center gap-2">
                  <AlertCircle className="h-4 w-4 shrink-0" />
                  <span>{moderationError}</span>
                </div>
              )}

              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1.5">
                  Select Action / Target Status
                </label>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
                  <button
                    type="button"
                    onClick={() => setTargetStatus("MODERATED")}
                    className={`p-3 rounded-lg border text-left text-xs transition-colors ${
                      targetStatus === "MODERATED"
                        ? "border-rose-500 bg-rose-950/30 text-rose-200"
                        : "border-slate-800 bg-slate-950 text-slate-400 hover:bg-slate-900"
                    }`}
                  >
                    <div className="font-semibold flex items-center gap-1.5">
                      <ShieldAlert className="h-3.5 w-3.5 text-rose-400" />
                      MODERATED
                    </div>
                    <div className="text-[11px] mt-1 text-slate-400">
                      Takedown from public streaming catalogue
                    </div>
                  </button>

                  <button
                    type="button"
                    onClick={() => setTargetStatus("READY")}
                    className={`p-3 rounded-lg border text-left text-xs transition-colors ${
                      targetStatus === "READY"
                        ? "border-emerald-500 bg-emerald-950/30 text-emerald-200"
                        : "border-slate-800 bg-slate-950 text-slate-400 hover:bg-slate-900"
                    }`}
                  >
                    <div className="font-semibold flex items-center gap-1.5">
                      <CheckCircle2 className="h-3.5 w-3.5 text-emerald-400" />
                      READY
                    </div>
                    <div className="text-[11px] mt-1 text-slate-400">
                      Restore track to active streaming catalogue
                    </div>
                  </button>

                  <button
                    type="button"
                    onClick={() => setTargetStatus("FAILED")}
                    className={`p-3 rounded-lg border text-left text-xs transition-colors ${
                      targetStatus === "FAILED"
                        ? "border-amber-500 bg-amber-950/30 text-amber-200"
                        : "border-slate-800 bg-slate-950 text-slate-400 hover:bg-slate-900"
                    }`}
                  >
                    <div className="font-semibold flex items-center gap-1.5">
                      <AlertCircle className="h-3.5 w-3.5 text-amber-400" />
                      FAILED
                    </div>
                    <div className="text-[11px] mt-1 text-slate-400">
                      Flag as processing / transcoding defect
                    </div>
                  </button>
                </div>
              </div>

              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1.5">
                  Moderation Reason & Reference (Required)
                </label>
                <textarea
                  rows={4}
                  placeholder="e.g., Copyright DMCA notice received from Universal Music Group; ticket #49201..."
                  value={moderationReason}
                  onChange={(e) => setModerationReason(e.target.value)}
                  className="w-full rounded-lg border border-slate-700 bg-slate-900 p-2.5 text-xs text-slate-200 placeholder:text-slate-500 focus:outline-none focus:border-purple-500"
                />
              </div>

              <div className="pt-2">
                <Button
                  variant={targetStatus === "MODERATED" ? "danger" : "primary"}
                  size="sm"
                  disabled={!moderationReason.trim()}
                  isLoading={moderateMutation.isPending}
                  onClick={() =>
                    moderateMutation.mutate({
                      status: targetStatus,
                      reason: moderationReason,
                    })
                  }
                  className="text-xs"
                >
                  <ShieldAlert className="h-3.5 w-3.5 mr-1.5" />
                  Confirm Status Change to {targetStatus}
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {/* TAB 5: TRACK AUDIT HISTORY */}
      {activeTab === "audit" && (
        <Card className="border-slate-800 bg-slate-900/60 backdrop-blur">
          <CardHeader className="pb-3">
            <CardTitle className="text-sm font-semibold text-slate-200 flex items-center justify-between">
              <span className="flex items-center gap-2">
                <History className="h-4 w-4 text-purple-400" />
                Track Administrative Audit Trail
              </span>
              <span className="text-xs font-normal text-slate-400">
                {track.audit_logs?.length ?? 0} events recorded
              </span>
            </CardTitle>
            <CardDescription className="text-xs text-slate-400">
              Immutable log of administrator actions, takedown reasons, and metadata adjustments
            </CardDescription>
          </CardHeader>
          <CardContent>
            {track.audit_logs && track.audit_logs.length > 0 ? (
              <div className="space-y-3">
                {track.audit_logs.map((log: AdminAuditLog) => (
                  <div
                    key={log.id}
                    className="p-3.5 rounded-lg border border-slate-800 bg-slate-950 space-y-1.5 text-xs"
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <Badge variant="outline" className="font-mono text-[10px]">
                          {log.action}
                        </Badge>
                        <span className="text-slate-300 font-medium">
                          by {log.actor_email || log.actor_id}
                        </span>
                      </div>
                      <span className="text-slate-500 text-[11px]">
                        {formatDate(log.created_at)}
                      </span>
                    </div>

                    {log.reason && (
                      <div className="text-slate-300 bg-slate-900/60 p-2 rounded border border-slate-800/80 text-[11px]">
                        <strong className="text-slate-400">Reason: </strong>
                        {log.reason}
                      </div>
                    )}

                    {log.details && Object.keys(log.details).length > 0 && (
                      <div className="text-slate-400 font-mono text-[10px] break-all">
                        {JSON.stringify(log.details)}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            ) : (
              <div className="text-center py-8 text-xs text-slate-400">
                No administrative audit events recorded for this track yet.
              </div>
            )}
          </CardContent>
        </Card>
      )}
    </div>
  );
}

export default function AdminTrackDetailPage() {
  return (
    <React.Suspense
      fallback={
        <div className="flex flex-col items-center justify-center min-h-[450px] space-y-4">
          <RefreshCw className="h-8 w-8 text-purple-400 animate-spin" />
          <p className="text-sm text-slate-400">Loading catalog track detail...</p>
        </div>
      }
    >
      <AdminTrackDetailContent />
    </React.Suspense>
  );
}
