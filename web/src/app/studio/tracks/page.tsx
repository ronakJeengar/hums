"use client";

import * as React from "react";
import Link from "next/link";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { ColumnDef, RowSelectionState } from "@tanstack/react-table";
import {
  AlertCircle,
  CheckCircle2,
  ChevronRight,
  Clock,
  Edit3,
  ExternalLink,
  Eye,
  FileAudio,
  Filter,
  Globe,
  Lock,
  PlusCircle,
  RefreshCw,
  Search,
  Sparkles,
  Tag,
  X,
} from "lucide-react";
import { DataTable } from "@/components/ui/data-table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge, StatusBadge } from "@/components/ui/badge";
import { Dialog } from "@/components/ui/dialog";
import { api } from "@/lib/api/client";
import { formatDate, formatDuration, formatNumber } from "@/lib/utils";
import { BulkItemResult, BulkTrackActionResult, CreatorTrackItem } from "@/types";

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

export default function CreatorTracksPage() {
  const queryClient = useQueryClient();
  const [page, setPage] = React.useState(1);
  const [search, setSearch] = React.useState("");
  const [statusFilter, setStatusFilter] = React.useState<string>("");
  const [publishingFilter, setPublishingFilter] = React.useState<string>("");
  const [genreFilter, setGenreFilter] = React.useState<string>("");
  const [sortBy, setSortBy] = React.useState<string>("created_at");
  const [sortOrder, setSortOrder] = React.useState<"asc" | "desc">("desc");

  // Selection & Bulk Actions
  const [rowSelection, setRowSelection] = React.useState<RowSelectionState>({});
  const [isBulkGenreModalOpen, setIsBulkGenreModalOpen] = React.useState(false);
  const [bulkGenreValue, setBulkGenreValue] = React.useState("Ambient");
  const [bulkResultModal, setBulkResultModal] = React.useState<BulkTrackActionResult | null>(null);

  // Single Edit Modal
  const [selectedTrack, setSelectedTrack] = React.useState<CreatorTrackItem | null>(null);
  const [isEditModalOpen, setIsEditModalOpen] = React.useState(false);
  const [editTitle, setEditTitle] = React.useState("");
  const [editAlbum, setEditAlbum] = React.useState("");
  const [editGenre, setEditGenre] = React.useState("");
  const [editDescription, setEditDescription] = React.useState("");
  const [modalError, setModalError] = React.useState<string | null>(null);

  // Publishing toggle confirmation modal
  const [publishingTrack, setPublishingTrack] = React.useState<CreatorTrackItem | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: [
      "studio-tracks",
      page,
      search,
      statusFilter,
      publishingFilter,
      genreFilter,
      sortBy,
      sortOrder,
    ],
    queryFn: () =>
      api.studio.getTracks({
        page,
        size: 20,
        search: search || undefined,
        status: statusFilter || undefined,
        is_published:
          publishingFilter === "published"
            ? true
            : publishingFilter === "unpublished"
            ? false
            : undefined,
        genre: genreFilter || undefined,
        sort_by: sortBy,
        sort_order: sortOrder,
      }),
  });

  const updateMutation = useMutation({
    mutationFn: ({
      trackId,
      data,
    }: {
      trackId: string;
      data: {
        title: string;
        album_name?: string;
        genre?: string;
        description?: string;
      };
    }) => api.studio.updateTrack(trackId, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["studio-tracks"] });
      queryClient.invalidateQueries({ queryKey: ["studio-dashboard"] });
      setIsEditModalOpen(false);
      setModalError(null);
    },
    onError: (err: Error) => {
      setModalError(err?.message || "Failed to update track");
    },
  });

  const publishingMutation = useMutation({
    mutationFn: ({ trackId, isPublished }: { trackId: string; isPublished: boolean }) =>
      api.studio.setPublishing(trackId, isPublished),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["studio-tracks"] });
      queryClient.invalidateQueries({ queryKey: ["studio-dashboard"] });
      setPublishingTrack(null);
    },
    onError: (err: Error) => {
      alert(`Publishing update failed: ${err.message}`);
    },
  });

  const retryMutation = useMutation({
    mutationFn: (trackId: string) => api.studio.retryTrack(trackId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["studio-tracks"] });
    },
    onError: (err: Error) => {
      alert(`Retry failed: ${err.message}`);
    },
  });

  const bulkActionMutation = useMutation({
    mutationFn: (payload: {
      action: "publish" | "unpublish" | "retry" | "update_metadata";
      track_ids: string[];
      genre?: string;
    }) => api.studio.bulkAction(payload),
    onSuccess: (res) => {
      queryClient.invalidateQueries({ queryKey: ["studio-tracks"] });
      queryClient.invalidateQueries({ queryKey: ["studio-dashboard"] });
      setRowSelection({});
      setIsBulkGenreModalOpen(false);
      setBulkResultModal(res);
    },
    onError: (err: Error) => {
      alert(`Bulk action failed: ${err.message}`);
    },
  });

  const selectedTrackIds = React.useMemo(() => {
    return Object.keys(rowSelection).filter((k) => rowSelection[k]);
  }, [rowSelection]);

  const columns: ColumnDef<CreatorTrackItem>[] = [
    {
      id: "select",
      header: ({ table }) => (
        <input
          type="checkbox"
          checked={table.getIsAllPageRowsSelected()}
          onChange={(e) => table.toggleAllPageRowsSelected(!!e.target.checked)}
          className="rounded border-slate-700 bg-slate-900 text-purple-600 focus:ring-purple-500 cursor-pointer"
          aria-label="Select all tracks"
        />
      ),
      cell: ({ row }) => (
        <input
          type="checkbox"
          checked={row.getIsSelected()}
          onChange={(e) => row.toggleSelected(!!e.target.checked)}
          className="rounded border-slate-700 bg-slate-900 text-purple-600 focus:ring-purple-500 cursor-pointer"
          aria-label={`Select track ${row.original.title}`}
        />
      ),
      enableSorting: false,
    },
    {
      accessorKey: "title",
      header: "Track",
      cell: ({ row }) => {
        const t = row.original;
        return (
          <div className="flex items-center gap-3">
            <div className="h-10 w-10 rounded-lg bg-slate-800 border border-slate-700/60 overflow-hidden flex items-center justify-center text-slate-400 shrink-0 relative group">
              {t.cover_image_key ? (
                <img
                  src={`http://127.0.0.1:8001/storage/${t.cover_image_key}`}
                  alt={t.title}
                  className="h-full w-full object-cover"
                  onError={(e) => {
                    // Fallback to placeholder if image fails
                    (e.target as HTMLElement).style.display = "none";
                  }}
                />
              ) : (
                <FileAudio className="h-4 w-4 text-purple-400" />
              )}
            </div>
            <div className="min-w-0">
              <Link
                href={`/studio/tracks/${t.id}`}
                className="font-semibold text-slate-100 hover:text-purple-400 transition-colors flex items-center gap-1.5 truncate group"
              >
                <span>{t.title}</span>
                <ChevronRight className="h-3 w-3 opacity-0 group-hover:opacity-100 transition-opacity text-slate-500" />
              </Link>
              <div className="text-xs text-slate-400 truncate">
                {t.album_name ? `Album: ${t.album_name}` : "Single Release"}
              </div>
            </div>
          </div>
        );
      },
    },
    {
      accessorKey: "genre",
      header: "Genre",
      cell: ({ row }) => (
        <span className="inline-flex items-center px-2 py-0.5 rounded text-xs bg-slate-800/80 text-slate-300 border border-slate-700/50">
          {row.original.genre || "Unassigned"}
        </span>
      ),
    },
    {
      accessorKey: "duration_seconds",
      header: "Duration",
      cell: ({ row }) => (
        <div className="flex items-center gap-1.5 text-xs text-slate-300">
          <Clock className="h-3.5 w-3.5 text-slate-500" />
          {formatDuration(row.original.duration_seconds)}
        </div>
      ),
    },
    {
      accessorKey: "status",
      header: "Processing",
      cell: ({ row }) => <StatusBadge status={row.original.status} />,
    },
    {
      accessorKey: "is_published",
      header: "Publishing",
      cell: ({ row }) => {
        const t = row.original;
        const isReady = t.status === "READY";
        return (
          <div className="flex items-center gap-2">
            <button
              onClick={() => {
                if (!isReady && !t.is_published) {
                  alert("Track must complete processing (READY) before it can be published.");
                  return;
                }
                setPublishingTrack(t);
              }}
              title={
                !isReady && !t.is_published
                  ? "Track cannot be published until media transcoding is READY"
                  : t.is_published
                  ? "Click to unpublish"
                  : "Click to publish"
              }
              className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-medium border transition-colors ${
                t.is_published
                  ? "bg-emerald-950/60 text-emerald-300 border-emerald-800/60 hover:bg-emerald-900/40"
                  : "bg-slate-800/80 text-slate-400 border-slate-700 hover:bg-slate-750"
              }`}
            >
              {t.is_published ? (
                <>
                  <Globe className="h-3 w-3 text-emerald-400" />
                  Published
                </>
              ) : (
                <>
                  <Lock className="h-3 w-3 text-slate-400" />
                  Draft
                </>
              )}
            </button>
          </div>
        );
      },
    },
    {
      accessorKey: "play_count",
      header: "Streams",
      cell: ({ row }) => (
        <span className="font-mono text-xs text-slate-300">
          {formatNumber(row.original.play_count)}
        </span>
      ),
    },
    {
      accessorKey: "created_at",
      header: "Created",
      cell: ({ row }) => (
        <span className="text-xs text-slate-400">
          {formatDate(row.original.created_at)}
        </span>
      ),
    },
    {
      id: "actions",
      header: "Actions",
      cell: ({ row }) => {
        const t = row.original;
        return (
          <div className="flex items-center gap-1.5">
            <Link href={`/studio/tracks/${t.id}`}>
              <Button variant="ghost" size="sm" title="View Track Details & Renditions">
                <Eye className="h-3.5 w-3.5 text-slate-300" />
              </Button>
            </Link>

            <Button
              variant="outline"
              size="sm"
              onClick={() => {
                setSelectedTrack(t);
                setEditTitle(t.title);
                setEditAlbum(t.album_name || "");
                setEditGenre(t.genre || "");
                setEditDescription("");
                setModalError(null);
                setIsEditModalOpen(true);
              }}
              title="Edit Metadata"
            >
              <Edit3 className="h-3.5 w-3.5" />
            </Button>

            {t.status === "FAILED" && (
              <Button
                variant="ghost"
                size="sm"
                onClick={() => retryMutation.mutate(t.id)}
                isLoading={retryMutation.isPending}
                title="Retry Transcoding"
              >
                <RefreshCw className="h-3.5 w-3.5 text-amber-400" />
              </Button>
            )}
          </div>
        );
      },
    },
  ];

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-white flex items-center gap-2">
            <span>Media Library & Content Studio</span>
          </h1>
          <p className="text-xs text-slate-400 mt-1">
            Authoritative media catalog with audio renditions, publishing lifecycle controls, and bulk management.
          </p>
        </div>
        <Link href="/studio/upload">
          <Button variant="primary" size="sm" className="shadow-lg shadow-purple-900/30">
            <PlusCircle className="h-4 w-4 mr-1.5" />
            Upload New Audio
          </Button>
        </Link>
      </div>

      {/* Filter and Search Bar */}
      <div className="bg-slate-900/60 p-4 rounded-xl border border-slate-800 space-y-3">
        <div className="flex flex-wrap items-center gap-3">
          <div className="w-full sm:w-72">
            <Input
              placeholder="Search by title, album, artist..."
              icon={<Search className="h-4 w-4 text-slate-400" />}
              value={search}
              onChange={(e) => {
                setSearch(e.target.value);
                setPage(1);
              }}
            />
          </div>

          <div className="flex items-center gap-2 flex-wrap">
            {/* Status Filter */}
            <select
              value={statusFilter}
              onChange={(e) => {
                setStatusFilter(e.target.value);
                setPage(1);
              }}
              className="h-9.5 rounded-lg border border-slate-700 bg-slate-900 px-3 text-xs text-slate-200 focus:outline-none focus:border-purple-500"
            >
              <option value="">All Processing States</option>
              <option value="READY">Ready & Streamable</option>
              <option value="PROCESSING">Processing Jobs</option>
              <option value="FAILED">Transcode Failed</option>
              <option value="MODERATED">Under Moderation</option>
            </select>

            {/* Publishing Filter */}
            <select
              value={publishingFilter}
              onChange={(e) => {
                setPublishingFilter(e.target.value);
                setPage(1);
              }}
              className="h-9.5 rounded-lg border border-slate-700 bg-slate-900 px-3 text-xs text-slate-200 focus:outline-none focus:border-purple-500"
            >
              <option value="">All Publishing States</option>
              <option value="published">Published (Public)</option>
              <option value="unpublished">Draft / Unpublished</option>
            </select>

            {/* Genre Filter */}
            <select
              value={genreFilter}
              onChange={(e) => {
                setGenreFilter(e.target.value);
                setPage(1);
              }}
              className="h-9.5 rounded-lg border border-slate-700 bg-slate-900 px-3 text-xs text-slate-200 focus:outline-none focus:border-purple-500"
            >
              <option value="">All Genres</option>
              {GENRE_OPTIONS.map((g) => (
                <option key={g} value={g}>
                  {g}
                </option>
              ))}
            </select>

            {/* Sort Field */}
            <select
              value={sortBy}
              onChange={(e) => {
                setSortBy(e.target.value);
                setPage(1);
              }}
              className="h-9.5 rounded-lg border border-slate-700 bg-slate-900 px-3 text-xs text-slate-200 focus:outline-none focus:border-purple-500"
            >
              <option value="created_at">Sort by Date</option>
              <option value="title">Sort by Title</option>
              <option value="duration_seconds">Sort by Duration</option>
            </select>

            <button
              onClick={() => setSortOrder((o) => (o === "asc" ? "desc" : "asc"))}
              className="h-9.5 px-3 rounded-lg border border-slate-700 bg-slate-900 text-xs text-slate-300 hover:bg-slate-800 transition-colors"
              title="Toggle sort direction"
            >
              {sortOrder === "asc" ? "Oldest First ↑" : "Newest First ↓"}
            </button>

            {(search || statusFilter || publishingFilter || genreFilter) && (
              <Button
                variant="ghost"
                size="sm"
                onClick={() => {
                  setSearch("");
                  setStatusFilter("");
                  setPublishingFilter("");
                  setGenreFilter("");
                  setPage(1);
                }}
                className="text-xs text-slate-400 hover:text-slate-100"
              >
                <X className="h-3.5 w-3.5 mr-1" />
                Reset Filters
              </Button>
            )}
          </div>
        </div>
      </div>

      {/* Floating Bulk Actions Toolbar */}
      {selectedTrackIds.length > 0 && (
        <div className="sticky top-4 z-30 flex items-center justify-between p-3 rounded-xl bg-purple-950/90 border border-purple-800/80 shadow-2xl backdrop-blur-md animate-in fade-in slide-in-from-top-2">
          <div className="flex items-center gap-3">
            <span className="flex h-6 w-6 items-center justify-center rounded-full bg-purple-600 text-xs font-bold text-white">
              {selectedTrackIds.length}
            </span>
            <span className="text-xs font-medium text-purple-200">
              {selectedTrackIds.length} {selectedTrackIds.length === 1 ? "track" : "tracks"} selected
            </span>
          </div>

          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() =>
                bulkActionMutation.mutate({
                  action: "publish",
                  track_ids: selectedTrackIds,
                })
              }
              isLoading={bulkActionMutation.isPending}
              className="border-emerald-700 bg-emerald-950/40 text-emerald-300 hover:bg-emerald-900/60"
            >
              <Globe className="h-3.5 w-3.5 mr-1 text-emerald-400" />
              Bulk Publish
            </Button>

            <Button
              variant="outline"
              size="sm"
              onClick={() =>
                bulkActionMutation.mutate({
                  action: "unpublish",
                  track_ids: selectedTrackIds,
                })
              }
              isLoading={bulkActionMutation.isPending}
              className="border-amber-700 bg-amber-950/40 text-amber-300 hover:bg-amber-900/60"
            >
              <Lock className="h-3.5 w-3.5 mr-1 text-amber-400" />
              Bulk Unpublish
            </Button>

            <Button
              variant="outline"
              size="sm"
              onClick={() =>
                bulkActionMutation.mutate({
                  action: "retry",
                  track_ids: selectedTrackIds,
                })
              }
              isLoading={bulkActionMutation.isPending}
              className="border-slate-700 text-slate-200"
            >
              <RefreshCw className="h-3.5 w-3.5 mr-1 text-purple-400" />
              Bulk Retry
            </Button>

            <Button
              variant="outline"
              size="sm"
              onClick={() => setIsBulkGenreModalOpen(true)}
              className="border-slate-700 text-slate-200"
            >
              <Tag className="h-3.5 w-3.5 mr-1 text-sky-400" />
              Set Genre
            </Button>

            <Button
              variant="ghost"
              size="sm"
              onClick={() => setRowSelection({})}
              className="text-xs text-slate-400 hover:text-white"
            >
              Clear
            </Button>
          </div>
        </div>
      )}

      {/* Main Table */}
      <DataTable
        columns={columns}
        data={data?.items ?? []}
        isLoading={isLoading}
        page={page}
        totalPages={data?.total_pages ?? 1}
        total={data?.total}
        onPageChange={(newPage) => setPage(newPage)}
        rowSelection={rowSelection}
        onRowSelectionChange={setRowSelection}
        getRowId={(row) => row.id}
      />

      {/* Publishing Toggle Confirmation Dialog */}
      <Dialog
        open={!!publishingTrack}
        onOpenChange={(open) => !open && setPublishingTrack(null)}
        title={publishingTrack?.is_published ? "Unpublish Track?" : "Publish Track?"}
        description={`Track: "${publishingTrack?.title}"`}
        footer={
          <>
            <Button variant="ghost" onClick={() => setPublishingTrack(null)}>
              Cancel
            </Button>
            <Button
              variant={publishingTrack?.is_published ? "outline" : "primary"}
              onClick={() => {
                if (publishingTrack) {
                  publishingMutation.mutate({
                    trackId: publishingTrack.id,
                    isPublished: !publishingTrack.is_published,
                  });
                }
              }}
              isLoading={publishingMutation.isPending}
            >
              {publishingTrack?.is_published ? "Confirm Unpublish" : "Publish to Platform"}
            </Button>
          </>
        }
      >
        <div className="space-y-3 text-xs text-slate-300">
          {publishingTrack?.is_published ? (
            <p>
              Unpublishing this track will transition it to <strong className="text-amber-400">Draft</strong> mode.
              Listeners will no longer be able to discover or stream this track until it is published again.
            </p>
          ) : (
            <p>
              Publishing will make this track visible in your public artist profile, search, and platform discovery.
              The track must have already completed media transcoding (<strong className="text-emerald-400">READY</strong>).
            </p>
          )}
        </div>
      </Dialog>

      {/* Bulk Genre Update Modal */}
      <Dialog
        open={isBulkGenreModalOpen}
        onOpenChange={setIsBulkGenreModalOpen}
        title="Bulk Update Track Genre"
        description={`Update genre across ${selectedTrackIds.length} selected tracks`}
        footer={
          <>
            <Button variant="ghost" onClick={() => setIsBulkGenreModalOpen(false)}>
              Cancel
            </Button>
            <Button
              variant="primary"
              onClick={() =>
                bulkActionMutation.mutate({
                  action: "update_metadata",
                  track_ids: selectedTrackIds,
                  genre: bulkGenreValue,
                })
              }
              isLoading={bulkActionMutation.isPending}
            >
              Apply to Selected
            </Button>
          </>
        }
      >
        <div className="space-y-3">
          <label className="text-xs font-medium text-slate-300">Target Genre</label>
          <select
            value={bulkGenreValue}
            onChange={(e) => setBulkGenreValue(e.target.value)}
            className="w-full h-10 rounded-lg border border-slate-700 bg-slate-900 px-3 text-sm text-slate-200 focus:outline-none focus:border-purple-500"
          >
            {GENRE_OPTIONS.map((g) => (
              <option key={g} value={g}>
                {g}
              </option>
            ))}
          </select>
        </div>
      </Dialog>

      {/* Bulk Results Summary Modal */}
      <Dialog
        open={!!bulkResultModal}
        onOpenChange={(open) => !open && setBulkResultModal(null)}
        title="Bulk Action Results"
        description={`Executed ${bulkResultModal?.action} on ${bulkResultModal?.total} tracks`}
        footer={
          <Button variant="primary" onClick={() => setBulkResultModal(null)}>
            Dismiss
          </Button>
        }
      >
        {bulkResultModal && (
          <div className="space-y-4">
            <div className="flex items-center gap-3 p-3 rounded-lg bg-slate-800/60 border border-slate-700/60 text-xs">
              <span className="text-emerald-400 font-semibold">
                ✓ {bulkResultModal.succeeded} succeeded
              </span>
              <span className="text-slate-500">|</span>
              <span className={bulkResultModal.failed > 0 ? "text-rose-400 font-semibold" : "text-slate-400"}>
                ✗ {bulkResultModal.failed} failed
              </span>
            </div>

            <div className="max-h-60 overflow-y-auto space-y-2 pr-1">
              {bulkResultModal.results.map((r, i) => (
                <div
                  key={r.track_id || i}
                  className="flex items-start justify-between gap-2 p-2.5 rounded-lg bg-slate-950/60 border border-slate-800/80 text-xs"
                >
                  <div className="min-w-0">
                    <div className="font-medium text-slate-200 truncate">
                      {r.title || `Track ${r.track_id.slice(0, 8)}...`}
                    </div>
                    {r.error && (
                      <div className="text-rose-400 text-2xs mt-0.5">{r.error}</div>
                    )}
                    {r.message && !r.error && (
                      <div className="text-slate-400 text-2xs mt-0.5">{r.message}</div>
                    )}
                  </div>
                  <div>
                    {r.status === "success" ? (
                      <span className="inline-flex items-center gap-1 text-emerald-400 text-2xs font-bold">
                        <CheckCircle2 className="h-3.5 w-3.5" />
                        OK
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-1 text-rose-400 text-2xs font-bold">
                        <AlertCircle className="h-3.5 w-3.5" />
                        ERR
                      </span>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </Dialog>

      {/* Edit Track Modal */}
      <Dialog
        open={isEditModalOpen}
        onOpenChange={setIsEditModalOpen}
        title="Edit Track Metadata"
        description={`Editing "${selectedTrack?.title}"`}
        footer={
          <>
            <Button
              variant="ghost"
              onClick={() => {
                setIsEditModalOpen(false);
                setModalError(null);
              }}
            >
              Cancel
            </Button>
            <Button
              variant="primary"
              onClick={() => {
                if (selectedTrack) {
                  updateMutation.mutate({
                    trackId: selectedTrack.id,
                    data: {
                      title: editTitle,
                      album_name: editAlbum || undefined,
                      genre: editGenre || undefined,
                      description: editDescription || undefined,
                    },
                  });
                }
              }}
              isLoading={updateMutation.isPending}
            >
              Save Metadata
            </Button>
          </>
        }
      >
        <div className="space-y-4">
          {modalError && (
            <div className="p-3 rounded-lg bg-rose-950/50 border border-rose-800/60 text-xs text-rose-300">
              {modalError}
            </div>
          )}

          <div>
            <label className="text-xs font-medium text-slate-300 block mb-1">
              Title *
            </label>
            <Input
              value={editTitle}
              onChange={(e) => setEditTitle(e.target.value)}
              placeholder="Track title"
            />
          </div>

          <div>
            <label className="text-xs font-medium text-slate-300 block mb-1">
              Album / Collection Name
            </label>
            <Input
              value={editAlbum}
              onChange={(e) => setEditAlbum(e.target.value)}
              placeholder="e.g. Echoes of Midnight"
            />
          </div>

          <div>
            <label className="text-xs font-medium text-slate-300 block mb-1">
              Genre
            </label>
            <select
              value={editGenre}
              onChange={(e) => setEditGenre(e.target.value)}
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
              Track Description / Liner Notes
            </label>
            <textarea
              value={editDescription}
              onChange={(e) => setEditDescription(e.target.value)}
              placeholder="Provide background, instrumentation, or credits..."
              rows={3}
              className="w-full rounded-lg border border-slate-700 bg-slate-900 p-2.5 text-xs text-slate-200 focus:outline-none focus:border-purple-500"
            />
          </div>
        </div>
      </Dialog>
    </div>
  );
}
