"use client";

import * as React from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { ColumnDef } from "@tanstack/react-table";
import {
  FileAudio,
  RefreshCw,
  Search,
  ShieldAlert,
} from "lucide-react";
import { DataTable } from "@/components/ui/data-table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { StatusBadge } from "@/components/ui/badge";
import { Dialog } from "@/components/ui/dialog";
import { api } from "@/lib/api/client";
import { formatDate, formatDuration, formatNumber } from "@/lib/utils";
import { AdminTrackItem } from "@/types";

export default function AdminTracksPage() {
  const queryClient = useQueryClient();
  const [page, setPage] = React.useState(1);
  const [search, setSearch] = React.useState("");
  const [statusFilter, setStatusFilter] = React.useState<string>("");

  const [selectedTrack, setSelectedTrack] = React.useState<AdminTrackItem | null>(null);
  const [isModerateModalOpen, setIsModerateModalOpen] = React.useState(false);
  const [targetStatus, setTargetStatus] = React.useState<"READY" | "MODERATED" | "FAILED">("MODERATED");
  const [moderationReason, setModerationReason] = React.useState("");
  const [modalError, setModalError] = React.useState<string | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["admin-tracks", page, search, statusFilter],
    queryFn: () =>
      api.admin.getTracks({
        page,
        size: 20,
        search: search || undefined,
        status: statusFilter || undefined,
      }),
  });

  const moderateMutation = useMutation({
    mutationFn: ({ trackId, status, reason }: { trackId: string; status: "READY" | "MODERATED" | "FAILED"; reason: string }) =>
      api.admin.moderateTrack(trackId, status, reason),
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

  const columns: ColumnDef<AdminTrackItem>[] = [
    {
      accessorKey: "title",
      header: "Track Title",
      cell: ({ row }) => {
        const t = row.original;
        return (
          <div className="flex items-center gap-3">
            <div className="h-9 w-9 rounded-lg bg-slate-800 flex items-center justify-center text-slate-400 shrink-0">
              <FileAudio className="h-4 w-4" />
            </div>
            <div>
              <div className="font-medium text-slate-100">{t.title}</div>
              <div className="text-xs text-slate-400">
                {t.artist_name || "Unknown Artist"} {t.album_name ? `• ${t.album_name}` : ""}
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
        <span className="text-xs text-slate-300">
          {row.original.genre || "—"}
        </span>
      ),
    },
    {
      accessorKey: "duration_seconds",
      header: "Duration",
      cell: ({ row }) => formatDuration(row.original.duration_seconds),
    },
    {
      accessorKey: "status",
      header: "Status",
      cell: ({ row }) => <StatusBadge status={row.original.status} />,
    },
    {
      accessorKey: "play_count",
      header: "Plays",
      cell: ({ row }) => formatNumber(row.original.play_count),
    },
    {
      accessorKey: "created_at",
      header: "Uploaded",
      cell: ({ row }) => formatDate(row.original.created_at),
    },
    {
      id: "actions",
      header: "Actions",
      cell: ({ row }) => {
        const t = row.original;
        return (
          <div className="flex items-center gap-2">
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
            >
              <ShieldAlert className="h-3.5 w-3.5 mr-1 text-purple-400" />
              <span>{t.status === "MODERATED" ? "Restore" : "Moderate"}</span>
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
      <div>
        <h1 className="text-xl font-bold tracking-tight text-white">
          Content & Track Moderation
        </h1>
        <p className="text-xs text-slate-400 mt-1">
          Catalog monitoring, takedown actions, and transcoding retry triggers
        </p>
      </div>

      <div className="flex flex-wrap items-center gap-3">
        <div className="w-full sm:w-64">
          <Input
            placeholder="Search track or artist..."
            icon={<Search className="h-4 w-4" />}
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPage(1);
            }}
          />
        </div>

        <select
          value={statusFilter}
          onChange={(e) => {
            setStatusFilter(e.target.value);
            setPage(1);
          }}
          className="h-9.5 rounded-lg border border-slate-700/80 bg-slate-900/90 px-3 text-xs text-slate-200 focus:outline-none focus:border-purple-500"
        >
          <option value="">All Statuses</option>
          <option value="READY">Ready & Streamable</option>
          <option value="PROCESSING">Processing / Transcoding</option>
          <option value="FAILED">Transcoding Failed</option>
          <option value="MODERATED">Moderated (Taken Down)</option>
        </select>
      </div>

      <DataTable
        columns={columns}
        data={data?.items ?? []}
        isLoading={isLoading}
        page={page}
        totalPages={data?.total_pages ?? 1}
        total={data?.total}
        onPageChange={(newPage) => setPage(newPage)}
      />

      {/* Moderate Track Modal */}
      <Dialog
        open={isModerateModalOpen}
        onOpenChange={setIsModerateModalOpen}
        title={`Moderate Track: "${selectedTrack?.title}"`}
        description={`Target ID: ${selectedTrack?.id}`}
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
              <option value="MODERATED">MODERATED (Takedown from public streaming)</option>
              <option value="READY">READY (Restore to active streaming catalog)</option>
              <option value="FAILED">FAILED (Flag processing defect)</option>
            </select>
          </div>

          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              Reason for Action (Required)
            </label>
            <textarea
              rows={3}
              placeholder="e.g., Copyright DMCA notification received from label..."
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
