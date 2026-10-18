"use client";

import * as React from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { ColumnDef } from "@tanstack/react-table";
import { CheckCircle, Search, ShieldCheck, XCircle } from "lucide-react";
import { DataTable } from "@/components/ui/data-table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Dialog } from "@/components/ui/dialog";
import { api } from "@/lib/api/client";
import { formatDate, formatNumber } from "@/lib/utils";
import { AdminCreatorItem } from "@/types";

export default function AdminCreatorsPage() {
  const queryClient = useQueryClient();
  const [page, setPage] = React.useState(1);
  const [search, setSearch] = React.useState("");

  const [selectedCreator, setSelectedCreator] = React.useState<AdminCreatorItem | null>(null);
  const [isVerifyModalOpen, setIsVerifyModalOpen] = React.useState(false);
  const [reason, setReason] = React.useState("");
  const [modalError, setModalError] = React.useState<string | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["admin-creators", page, search],
    queryFn: () =>
      api.admin.getCreators({
        page,
        size: 20,
        search: search || undefined,
      }),
  });

  const verifyMutation = useMutation({
    mutationFn: ({ creatorId, isVerified, reason }: { creatorId: string; isVerified: boolean; reason: string }) =>
      api.admin.verifyCreator(creatorId, isVerified, reason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-creators"] });
      setIsVerifyModalOpen(false);
      setReason("");
      setModalError(null);
    },
    onError: (err: Error) => {
      setModalError(err?.message || "Failed to update verification status");
    },
  });

  const columns: ColumnDef<AdminCreatorItem>[] = [
    {
      accessorKey: "name",
      header: "Creator / Artist",
      cell: ({ row }) => {
        const c = row.original;
        return (
          <div className="flex items-center gap-3">
            <div className="h-9 w-9 rounded-full bg-purple-950/60 border border-purple-800/40 flex items-center justify-center font-bold text-xs text-purple-300">
              {c.name.slice(0, 2).toUpperCase()}
            </div>
            <div>
              <div className="font-medium text-slate-100 flex items-center gap-1.5">
                <span>{c.name}</span>
                {c.is_verified && (
                  <CheckCircle className="h-3.5 w-3.5 text-purple-400 shrink-0" />
                )}
              </div>
              <div className="text-xs text-slate-400">
                {c.user_email || `@${c.username || "creator"}`}
              </div>
            </div>
          </div>
        );
      },
    },
    {
      accessorKey: "followers_count",
      header: "Followers",
      cell: ({ row }) => formatNumber(row.original.followers_count),
    },
    {
      accessorKey: "tracks_count",
      header: "Tracks in Catalog",
      cell: ({ row }) => formatNumber(row.original.tracks_count),
    },
    {
      accessorKey: "is_verified",
      header: "Verification",
      cell: ({ row }) => {
        const isVerified = row.original.is_verified;
        return isVerified ? (
          <Badge variant="purple">Verified Badge</Badge>
        ) : (
          <Badge variant="outline">Unverified</Badge>
        );
      },
    },
    {
      accessorKey: "created_at",
      header: "Artist Since",
      cell: ({ row }) => formatDate(row.original.created_at),
    },
    {
      id: "actions",
      header: "Actions",
      cell: ({ row }) => {
        const c = row.original;
        return (
          <Button
            variant="outline"
            size="sm"
            onClick={() => {
              setSelectedCreator(c);
              setModalError(null);
              setIsVerifyModalOpen(true);
            }}
          >
            <ShieldCheck className="h-3.5 w-3.5 mr-1 text-purple-400" />
            <span>{c.is_verified ? "Revoke Badge" : "Verify Artist"}</span>
          </Button>
        );
      },
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-bold tracking-tight text-white">
          Creator Catalog
        </h1>
        <p className="text-xs text-slate-400 mt-1">
          Review approved artists, catalog sizes, and manage verified authenticity badges
        </p>
      </div>

      <div className="w-full sm:w-64">
        <Input
          placeholder="Search artist name..."
          icon={<Search className="h-4 w-4" />}
          value={search}
          onChange={(e) => {
            setSearch(e.target.value);
            setPage(1);
          }}
        />
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

      {/* Verify / Revoke Modal */}
      <Dialog
        open={isVerifyModalOpen}
        onOpenChange={setIsVerifyModalOpen}
        title={selectedCreator?.is_verified ? "Revoke Verified Badge" : "Grant Verified Badge"}
        description={`Modifying verified badge for ${selectedCreator?.name}`}
        footer={
          <>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setIsVerifyModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              variant={selectedCreator?.is_verified ? "danger" : "primary"}
              size="sm"
              isLoading={verifyMutation.isPending}
              onClick={() => {
                if (!selectedCreator) return;
                verifyMutation.mutate({
                  creatorId: selectedCreator.id,
                  isVerified: !selectedCreator.is_verified,
                  reason,
                });
              }}
            >
              Confirm
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

          <p className="text-xs text-slate-300">
            {selectedCreator?.is_verified
              ? "This will remove the public blue/purple verified badge from the artist profile."
              : "Verified badges signify authentic artist identities and grant higher ranking in discovery."}
          </p>

          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              Audit Reason
            </label>
            <textarea
              rows={3}
              placeholder="e.g., Identity confirmed via official management email..."
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              className="w-full rounded-lg border border-slate-700 bg-slate-900 p-2.5 text-xs text-slate-200 placeholder:text-slate-500 focus:outline-none focus:border-purple-500"
            />
          </div>
        </div>
      </Dialog>
    </div>
  );
}
