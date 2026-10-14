"use client";

import * as React from "react";
import Link from "next/link";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { ColumnDef } from "@tanstack/react-table";
import {
  Edit3,
  FileAudio,
  PlusCircle,
  RefreshCw,
  Search,
} from "lucide-react";
import { DataTable } from "@/components/ui/data-table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { StatusBadge } from "@/components/ui/badge";
import { Dialog } from "@/components/ui/dialog";
import { api } from "@/lib/api/client";
import { formatDate, formatDuration, formatNumber } from "@/lib/utils";
import { CreatorTrackItem } from "@/types";

export default function CreatorTracksPage() {
  const queryClient = useQueryClient();
  const [page, setPage] = React.useState(1);
  const [search, setSearch] = React.useState("");
  const [statusFilter, setStatusFilter] = React.useState<string>("");

  const [selectedTrack, setSelectedTrack] = React.useState<CreatorTrackItem | null>(null);
  const [isEditModalOpen, setIsEditModalOpen] = React.useState(false);
  const [editTitle, setEditTitle] = React.useState("");
  const [editAlbum, setEditAlbum] = React.useState("");
  const [editGenre, setEditGenre] = React.useState("");
  const [editDescription, setEditDescription] = React.useState("");
  const [modalError, setModalError] = React.useState<string | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["studio-tracks", page, search, statusFilter],
    queryFn: () =>
      api.studio.getTracks({
        page,
        size: 20,
        search: search || undefined,
        status: statusFilter || undefined,
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

  const retryMutation = useMutation({
    mutationFn: (trackId: string) => api.studio.retryTrack(trackId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["studio-tracks"] });
    },
  });

  const columns: ColumnDef<CreatorTrackItem>[] = [
    {
      accessorKey: "title",
      header: "Track",
      cell: ({ row }) => {
        const t = row.original;
        return (
          <div className="flex items-center gap-3">
            <div className="h-9 w-9 rounded-lg bg-slate-800 flex items-center justify-center text-slate-400 shrink-0">
              <FileAudio className="h-4 w-4" />
            </div>
            <div>
              <div className="font-semibold text-slate-100">{t.title}</div>
              <div className="text-xs text-slate-400">
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
        <span className="text-xs text-slate-300">{row.original.genre || "—"}</span>
      ),
    },
    {
      accessorKey: "duration_seconds",
      header: "Duration",
      cell: ({ row }) => formatDuration(row.original.duration_seconds),
    },
    {
      accessorKey: "status",
      header: "Processing Status",
      cell: ({ row }) => <StatusBadge status={row.original.status} />,
    },
    {
      accessorKey: "play_count",
      header: "Streams",
      cell: ({ row }) => formatNumber(row.original.play_count),
    },
    {
      accessorKey: "likes_count",
      header: "Likes",
      cell: ({ row }) => formatNumber(row.original.likes_count),
    },
    {
      accessorKey: "created_at",
      header: "Release Date",
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
                setEditTitle(t.title);
                setEditAlbum(t.album_name || "");
                setEditGenre(t.genre || "");
                setEditDescription("");
                setModalError(null);
                setIsEditModalOpen(true);
              }}
            >
              <Edit3 className="h-3.5 w-3.5 mr-1" />
              Edit
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
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold tracking-tight text-white">
            My Audio Catalog
          </h1>
          <p className="text-xs text-slate-400 mt-1">
            Manage release metadata, view streaming performance, and retry failed transcode jobs
          </p>
        </div>
        <Link href="/studio/upload">
          <Button variant="primary" size="sm">
            <PlusCircle className="h-4 w-4 mr-1.5" />
            Upload New Audio
          </Button>
        </Link>
      </div>

      <div className="flex flex-wrap items-center gap-3">
        <div className="w-full sm:w-64">
          <Input
            placeholder="Search my tracks..."
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
          <option value="PROCESSING">Processing</option>
          <option value="FAILED">Transcoding Failed</option>
          <option value="MODERATED">Moderated</option>
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
              size="sm"
              onClick={() => setIsEditModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              variant="primary"
              size="sm"
              isLoading={updateMutation.isPending}
              onClick={() => {
                if (!selectedTrack) return;
                updateMutation.mutate({
                  trackId: selectedTrack.id,
                  data: {
                    title: editTitle,
                    album_name: editAlbum || undefined,
                    genre: editGenre || undefined,
                    description: editDescription || undefined,
                  },
                });
              }}
            >
              Save Changes
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
              Track Title
            </label>
            <Input
              value={editTitle}
              onChange={(e) => setEditTitle(e.target.value)}
              placeholder="Track title"
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-medium text-slate-300 mb-1.5">
                Album / EP Name
              </label>
              <Input
                value={editAlbum}
                onChange={(e) => setEditAlbum(e.target.value)}
                placeholder="Optional album name"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-slate-300 mb-1.5">
                Primary Genre
              </label>
              <Input
                value={editGenre}
                onChange={(e) => setEditGenre(e.target.value)}
                placeholder="e.g., Electronic, Ambient"
              />
            </div>
          </div>

          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              Liner Notes / Description
            </label>
            <textarea
              rows={3}
              value={editDescription}
              onChange={(e) => setEditDescription(e.target.value)}
              placeholder="Add track story, credits, or instruments..."
              className="w-full rounded-lg border border-slate-700 bg-slate-900 p-2.5 text-xs text-slate-200 placeholder:text-slate-500 focus:outline-none focus:border-purple-500"
            />
          </div>
        </div>
      </Dialog>
    </div>
  );
}
