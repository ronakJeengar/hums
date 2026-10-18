"use client";

import * as React from "react";
import Link from "next/link";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { ColumnDef, RowSelectionState } from "@tanstack/react-table";
import {
  AlertCircle,
  CheckCircle2,
  ChevronRight,
  Eye,
  FileAudio,
  Filter,
  Globe,
  Lock,
  RefreshCw,
  Search,
  Shield,
  ShieldAlert,
  Sparkles,
  User,
  X,
} from "lucide-react";
import { DataTable } from "@/components/ui/data-table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge, StatusBadge } from "@/components/ui/badge";
import { Dialog } from "@/components/ui/dialog";
import { api } from "@/lib/api/client";
import { formatDate, formatDuration, formatNumber } from "@/lib/utils";
import {
  AdminTrackItem,
  BulkItemResult,
  BulkTrackActionResult,
} from "@/types";

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

export default function AdminTracksPage() {
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
  const [isBulkModerateModalOpen, setIsBulkModerateModalOpen] = React.useState(false);
  const [bulkTargetStatus, setBulkTargetStatus] = React.useState<"READY" | "MODERATED" | "FAILED">("MODERATED");
  const [bulkReason, setBulkReason] = React.useState("");
  const [bulkResultModal, setBulkResultModal] = React.useState<BulkTrackActionResult | null>(null);

  // Single Moderate Modal
  const [selectedTrack, setSelectedTrack] = React.useState<AdminTrackItem | null>(null);
  const [isModerateModalOpen, setIsModerateModalOpen] = React.useState(false);
  const [targetStatus, setTargetStatus] = React.useState<"READY" | "MODERATED" | "FAILED">("MODERATED");
  const [moderationReason, setModerationReason] = React.useState("");
  const [modalError, setModalError] = React.useState<string | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: [
      "admin-tracks",
      page,
      search,
      statusFilter,
      publishingFilter,
      genreFilter,
      sortBy,
      sortOrder,
    ],
    queryFn: () =>
      api.admin.getTracks({
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

  const moderateMutation = useMutation({
    mutationFn: ({
      trackId,
      status,
      reason,
    }: {
      trackId: string;
      status: "READY" | "MODERATED" | "FAILED";
      reason: string;
    }) => api.admin.moderateTrack(trackId, status, reason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-tracks"] });
      queryClient.invalidateQueries({ queryKey: ["admin-dashboard"] });
      setIsModerateModalOpen(false);
      setModerationReason("");
      setModalError(null);
    },
    onError: (err: Error) => {
      setModalError(err?.message || "Failed to moderate track");
    },
  });

  const retryMutation = useMutation({
    mutationFn: (trackId: string) => api.admin.retryTrack(trackId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-tracks"] });
    },
  });

  const bulkMutation = useMutation({
    mutationFn: (payload: {
      action: "publish" | "unpublish" | "retry" | "moderate";
      track_ids: string[];
      target_status?: "READY" | "MODERATED" | "FAILED";
      reason: string;
    }) => api.admin.bulkAction(payload),
    onSuccess: (res) => {
      setBulkResultModal(res);
      setRowSelection({});
      setIsBulkModerateModalOpen(false);
      setBulkReason("");
      queryClient.invalidateQueries({ queryKey: ["admin-tracks"] });
      queryClient.invalidateQueries({ queryKey: ["admin-dashboard"] });
    },
    onError: (err: Error) => {
      alert(`Bulk action failed: ${err.message}`);
    },
  });

  const selectedTrackIds = React.useMemo(() => {
    return Object.keys(rowSelection).filter((k) => rowSelection[k]);
  }, [rowSelection]);

  const columns: ColumnDef<AdminTrackItem>[] = [
    {
      id: "select",
      header: ({ table }) => (
        <input
          type="checkbox"
          checked={table.getIsAllPageRowsSelected()}
          onChange={(e) => table.toggleAllPageRowsSelected(!!e.target.checked)}
          aria-label="Select all tracks on current page"
          className="h-4 w-4 rounded border-slate-700 bg-slate-900 text-purple-600 focus:ring-purple-500 focus:ring-offset-slate-950"
        />
      ),
      cell: ({ row }) => (
        <input
          type="checkbox"
          checked={row.getIsSelected()}
          onChange={(e) => row.toggleSelected(!!e.target.checked)}
          aria-label={`Select track ${row.original.title}`}
          className="h-4 w-4 rounded border-slate-700 bg-slate-900 text-purple-600 focus:ring-purple-500 focus:ring-offset-slate-950"
        />
      ),
      enableSorting: false,
      enableHiding: false,
    },
    {
      accessorKey: "title",
      header: "Track Title & Artist",
      cell: ({ row }) => {
        const t = row.original;
        return (
          <div className="flex items-center gap-3 min-w-[200px]">
            <div className="h-10 w-10 rounded-lg bg-slate-800 border border-slate-700/60 overflow-hidden flex items-center justify-center text-slate-400 shrink-0">
              {t.cover_image_key ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={`http://127.0.0.1:8001/api/v1/audio/tracks/${t.id}/artwork?thumb=1`}
                  alt=""
                  className="h-full w-full object-cover"
                  onError={(e) => {
                    // Fallback to icon on error
                    (e.currentTarget as HTMLElement).style.display = "none";
                  }}
                />
              ) : (
                <FileAudio className="h-4 w-4 text-slate-500" />
              )}
            </div>
            <div className="min-w-0">
              <Link
                href={`/admin/tracks/${t.id}`}
                className="font-medium text-slate-100 hover:text-purple-400 transition-colors text-sm truncate block"
              >
                {t.title}
              </Link>
              <div className="text-xs text-slate-400 truncate">
                {t.artist_name || "Unknown Artist"}{" "}
                {t.album_name ? `• ${t.album_name}` : ""}
              </div>
            </div>
          </div>
        );
      },
    },
    {
      accessorKey: "owner",
      header: "Creator / Owner",
      cell: ({ row }) => {
        const t = row.original;
        return (
          <div className="text-xs">
            <div className="flex items-center gap-1.5 text-slate-200">
              <User className="h-3 w-3 text-purple-400 shrink-0" />
              <span className="truncate max-w-[150px]">
                {t.owner_email || t.artist_name || "Anonymous"}
              </span>
            </div>
            <div className="text-[10px] text-slate-500 font-mono truncate max-w-[150px]">
              {t.owner_id}
            </div>
          </div>
        );
      },
    },
    {
      accessorKey: "genre",
      header: "Genre",
      cell: ({ row }) => (
        <span className="text-xs text-slate-300">
          {row.original.genre || "—"}
        </span>
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
        const pub = row.original.is_published;
        return (
          <Badge
            variant={pub ? "success" : "default"}
            className="text-[10px] font-semibold gap-1"
          >
            {pub ? <Globe className="h-2.5 w-2.5" /> : <Lock className="h-2.5 w-2.5" />}
            {pub ? "Published" : "Draft / Private"}
          </Badge>
        );
      },
    },
    {
      accessorKey: "duration_seconds",
      header: "Duration",
      cell: ({ row }) => (
        <span className="text-xs text-slate-300">
          {formatDuration(row.original.duration_seconds)}
        </span>
      ),
    },
    {
      accessorKey: "play_count",
      header: "Plays",
      cell: ({ row }) => (
        <span className="text-xs text-slate-300 font-mono">
          {formatNumber(row.original.play_count)}
        </span>
      ),
    },
    {
      accessorKey: "created_at",
      header: "Uploaded",
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
            <Link href={`/admin/tracks/${t.id}`}>
              <Button variant="ghost" size="sm" title="View Full Inspection & Renditions">
                <Eye className="h-3.5 w-3.5 text-slate-300" />
              </Button>
            </Link>

            <Button
              variant="outline"
              size="sm"
              onClick={() => {
                setSelectedTrack(t);
                setTargetStatus(t.status === "MODERATED" ? "READY" : "MODERATED");
                setModerationReason("");
                setModalError(null);
                setIsModerateModalOpen(true);
              }}
              title="Moderate Content"
            >
              <ShieldAlert className="h-3.5 w-3.5 mr-1 text-purple-400" />
              <span className="text-xs">
                {t.status === "MODERATED" ? "Restore" : "Moderate"}
              </span>
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
    <div className="space-y-6 pb-20">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold tracking-tight text-white flex items-center gap-2">
            <Shield className="h-5 w-5 text-purple-400" />
            Track Catalog & Moderation
          </h1>
          <p className="text-xs text-slate-400 mt-1">
            Global catalog inspection, transcoding diagnostics, DMCA moderation, and bulk actions
          </p>
        </div>
      </div>

      {/* Filters Bar */}
      <div className="p-4 rounded-xl border border-slate-800 bg-slate-900/50 backdrop-blur space-y-3">
        <div className="flex flex-wrap items-center gap-3">
          <div className="w-full sm:w-64">
            <Input
              placeholder="Search title, artist, owner..."
              icon={<Search className="h-4 w-4" />}
              value={search}
              onChange={(e) => {
                setSearch(e.target.value);
                setPage(1);
              }}
            />
          </div>

          <div className="flex items-center gap-2">
            <Filter className="h-3.5 w-3.5 text-slate-400" />
            <span className="text-xs text-slate-400">Filters:</span>
          </div>

          <select
            value={statusFilter}
            onChange={(e) => {
              setStatusFilter(e.target.value);
              setPage(1);
            }}
            className="h-9 rounded-lg border border-slate-700/80 bg-slate-900/90 px-3 text-xs text-slate-200 focus:outline-none focus:border-purple-500"
          >
            <option value="">All Processing Statuses</option>
            <option value="READY">Ready & Streamable</option>
            <option value="PROCESSING">Processing / Transcoding</option>
            <option value="FAILED">Transcoding Failed</option>
            <option value="MODERATED">Moderated (Taken Down)</option>
            <option value="UPLOADED">Uploaded (Awaiting Queue)</option>
          </select>

          <select
            value={publishingFilter}
            onChange={(e) => {
              setPublishingFilter(e.target.value);
              setPage(1);
            }}
            className="h-9 rounded-lg border border-slate-700/80 bg-slate-900/90 px-3 text-xs text-slate-200 focus:outline-none focus:border-purple-500"
          >
            <option value="">All Publishing States</option>
            <option value="published">Published Only</option>
            <option value="unpublished">Draft / Private Only</option>
          </select>

          <select
            value={genreFilter}
            onChange={(e) => {
              setGenreFilter(e.target.value);
              setPage(1);
            }}
            className="h-9 rounded-lg border border-slate-700/80 bg-slate-900/90 px-3 text-xs text-slate-200 focus:outline-none focus:border-purple-500"
          >
            <option value="">All Genres</option>
            {GENRE_OPTIONS.map((g) => (
              <option key={g} value={g}>
                {g}
              </option>
            ))}
          </select>

          <div className="ml-auto flex items-center gap-2">
            <span className="text-xs text-slate-400">Sort:</span>
            <select
              value={sortBy}
              onChange={(e) => setSortBy(e.target.value)}
              className="h-9 rounded-lg border border-slate-700/80 bg-slate-900/90 px-3 text-xs text-slate-200 focus:outline-none focus:border-purple-500"
            >
              <option value="created_at">Date Uploaded</option>
              <option value="title">Title</option>
              <option value="play_count">Plays</option>
              <option value="likes_count">Likes</option>
              <option value="duration_seconds">Duration</option>
            </select>

            <Button
              variant="outline"
              size="sm"
              onClick={() => setSortOrder(sortOrder === "asc" ? "desc" : "asc")}
            >
              {sortOrder === "asc" ? "Asc" : "Desc"}
            </Button>
          </div>
        </div>
      </div>

      {/* Tracks Table */}
      <DataTable
        columns={columns}
        data={data?.items ?? []}
        isLoading={isLoading}
        page={page}
        totalPages={data?.total_pages ?? 1}
        total={data?.total}
        onPageChange={(newPage) => setPage(newPage)}
        enableRowSelection
        rowSelection={rowSelection}
        onRowSelectionChange={setRowSelection}
        getRowId={(row) => row.id}
      />

      {/* Floating Bulk Action Bar */}
      {selectedTrackIds.length > 0 && (
        <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-40 bg-slate-900/95 border border-purple-500/40 shadow-2xl shadow-purple-950/40 rounded-2xl px-5 py-3.5 backdrop-blur-md flex items-center gap-4 animate-in fade-in slide-in-from-bottom-4 duration-200">
          <div className="flex items-center gap-2">
            <span className="inline-flex items-center justify-center h-6 w-6 rounded-full bg-purple-600 text-[11px] font-bold text-white">
              {selectedTrackIds.length}
            </span>
            <span className="text-xs font-medium text-slate-200">
              tracks selected
            </span>
          </div>

          <div className="h-4 w-px bg-slate-700" />

          <div className="flex items-center gap-2">
            <Button
              variant="danger"
              size="sm"
              onClick={() => {
                setBulkTargetStatus("MODERATED");
                setBulkReason("");
                setIsBulkModerateModalOpen(true);
              }}
              className="text-xs"
            >
              <ShieldAlert className="h-3.5 w-3.5 mr-1.5" />
              Bulk Moderate
            </Button>

            <Button
              variant="outline"
              size="sm"
              onClick={() =>
                bulkMutation.mutate({
                  action: "publish",
                  track_ids: selectedTrackIds,
                  reason: "Bulk published by administrator",
                })
              }
              isLoading={bulkMutation.isPending}
              className="text-xs"
            >
              <Globe className="h-3.5 w-3.5 mr-1.5 text-emerald-400" />
              Publish
            </Button>

            <Button
              variant="outline"
              size="sm"
              onClick={() =>
                bulkMutation.mutate({
                  action: "unpublish",
                  track_ids: selectedTrackIds,
                  reason: "Bulk unpublished by administrator",
                })
              }
              isLoading={bulkMutation.isPending}
              className="text-xs"
            >
              <Lock className="h-3.5 w-3.5 mr-1.5 text-slate-400" />
              Unpublish
            </Button>

            <Button
              variant="outline"
              size="sm"
              onClick={() =>
                bulkMutation.mutate({
                  action: "retry",
                  track_ids: selectedTrackIds,
                  reason: "Bulk retry requested by administrator",
                })
              }
              isLoading={bulkMutation.isPending}
              className="text-xs"
            >
              <RefreshCw className="h-3.5 w-3.5 mr-1.5 text-amber-400" />
              Retry Failed
            </Button>
          </div>

          <div className="h-4 w-px bg-slate-700" />

          <Button
            variant="ghost"
            size="sm"
            onClick={() => setRowSelection({})}
            className="text-xs text-slate-400 hover:text-slate-200"
          >
            <X className="h-3.5 w-3.5 mr-1" />
            Clear
          </Button>
        </div>
      )}

      {/* Bulk Moderate Modal */}
      <Dialog
        open={isBulkModerateModalOpen}
        onOpenChange={setIsBulkModerateModalOpen}
        title={`Bulk Content Moderation (${selectedTrackIds.length} tracks)`}
        description="Apply an administrative status override across selected tracks. This action will be recorded in the security audit log."
        footer={
          <>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setIsBulkModerateModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              variant={bulkTargetStatus === "MODERATED" ? "danger" : "primary"}
              size="sm"
              isLoading={bulkMutation.isPending}
              disabled={!bulkReason.trim()}
              onClick={() => {
                bulkMutation.mutate({
                  action: "moderate",
                  track_ids: selectedTrackIds,
                  target_status: bulkTargetStatus,
                  reason: bulkReason,
                });
              }}
            >
              Apply to {selectedTrackIds.length} Tracks
            </Button>
          </>
        }
      >
        <div className="space-y-4">
          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              Target Status
            </label>
            <select
              value={bulkTargetStatus}
              onChange={(e) =>
                setBulkTargetStatus(
                  e.target.value as "READY" | "MODERATED" | "FAILED"
                )
              }
              className="w-full h-10 rounded-lg border border-slate-700 bg-slate-900 px-3 text-xs text-slate-200 focus:outline-none focus:border-purple-500"
            >
              <option value="MODERATED">MODERATED (Takedown from public catalogue)</option>
              <option value="READY">READY (Restore to active streaming catalogue)</option>
              <option value="FAILED">FAILED (Mark processing failed)</option>
            </select>
          </div>

          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              Reason / Justification (Required for Audit Trail)
            </label>
            <textarea
              rows={3}
              placeholder="e.g., Bulk DMCA takedown notice received from rights holder; or policy violation..."
              value={bulkReason}
              onChange={(e) => setBulkReason(e.target.value)}
              className="w-full rounded-lg border border-slate-700 bg-slate-900 p-2.5 text-xs text-slate-200 placeholder:text-slate-500 focus:outline-none focus:border-purple-500"
            />
          </div>
        </div>
      </Dialog>

      {/* Bulk Results Modal */}
      <Dialog
        open={!!bulkResultModal}
        onOpenChange={(open) => !open && setBulkResultModal(null)}
        title="Bulk Action Completed"
        description={`Processed ${bulkResultModal?.total ?? 0} tracks: ${
          bulkResultModal?.succeeded ?? 0
        } succeeded, ${bulkResultModal?.failed ?? 0} failed.`}
        footer={
          <Button
            variant="primary"
            size="sm"
            onClick={() => setBulkResultModal(null)}
          >
            Close
          </Button>
        }
      >
        <div className="space-y-3 max-h-72 overflow-y-auto pr-1">
          {bulkResultModal?.results.map((item: BulkItemResult) => (
            <div
              key={item.track_id}
              className="p-3 rounded-lg border border-slate-800 bg-slate-950 flex items-start justify-between gap-3 text-xs"
            >
              <div className="space-y-0.5">
                <div className="font-medium text-slate-200">
                  {item.title || `Track ID: ${item.track_id}`}
                </div>
                {item.error ? (
                  <div className="text-rose-400 text-[11px]">{item.error}</div>
                ) : (
                  <div className="text-emerald-400 text-[11px]">
                    {item.message || "Completed successfully"}
                  </div>
                )}
              </div>
              <div>
                {item.status === "success" ? (
                  <Badge variant="success" className="text-[10px]">
                    Success
                  </Badge>
                ) : (
                  <Badge variant="danger" className="text-[10px]">
                    Failed
                  </Badge>
                )}
              </div>
            </div>
          ))}
        </div>
      </Dialog>

      {/* Single Moderate Modal */}
      <Dialog
        open={isModerateModalOpen}
        onOpenChange={setIsModerateModalOpen}
        title={`Moderate Track: "${selectedTrack?.title}"`}
        description={`Track ID: ${selectedTrack?.id}`}
        footer={
          <>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setIsModerateModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              variant={targetStatus === "MODERATED" ? "danger" : "primary"}
              size="sm"
              isLoading={moderateMutation.isPending}
              disabled={!moderationReason.trim()}
              onClick={() => {
                if (!selectedTrack) return;
                moderateMutation.mutate({
                  trackId: selectedTrack.id,
                  status: targetStatus,
                  reason: moderationReason,
                });
              }}
            >
              Confirm Moderation
            </Button>
          </>
        }
      >
        <div className="space-y-4">
          {modalError && (
            <div className="p-2.5 rounded-lg bg-rose-950/50 border border-rose-800 text-xs text-rose-300">
              {modalError}
            </div>
          )}

          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              Set Content Status
            </label>
            <select
              value={targetStatus}
              onChange={(e) =>
                setTargetStatus(
                  e.target.value as "READY" | "MODERATED" | "FAILED"
                )
              }
              className="w-full h-10 rounded-lg border border-slate-700 bg-slate-900 px-3 text-xs text-slate-200 focus:outline-none focus:border-purple-500"
            >
              <option value="MODERATED">MODERATED (Takedown from public catalogue)</option>
              <option value="READY">READY (Restore to active streaming catalogue)</option>
              <option value="FAILED">FAILED (Mark processing defect)</option>
            </select>
          </div>

          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              Reason for Action (Required for Audit Trail)
            </label>
            <textarea
              rows={3}
              placeholder="e.g., Copyright DMCA notification received from rights holder..."
              value={moderationReason}
              onChange={(e) => setModerationReason(e.target.value)}
              className="w-full rounded-lg border border-slate-700 bg-slate-900 p-2.5 text-xs text-slate-200 placeholder:text-slate-500 focus:outline-none focus:border-purple-500"
            />
          </div>
        </div>
      </Dialog>
    </div>
  );
}
