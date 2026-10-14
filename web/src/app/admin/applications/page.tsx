"use client";

import * as React from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { ColumnDef } from "@tanstack/react-table";
import { Check, ExternalLink, ShieldCheck, X } from "lucide-react";
import { DataTable } from "@/components/ui/data-table";
import { Button } from "@/components/ui/button";
import { StatusBadge } from "@/components/ui/badge";
import { Dialog } from "@/components/ui/dialog";
import { api } from "@/lib/api/client";
import { formatDate } from "@/lib/utils";
import { CreatorApplication } from "@/types";

export default function AdminApplicationsPage() {
  const queryClient = useQueryClient();
  const [page, setPage] = React.useState(1);
  const [statusFilter, setStatusFilter] = React.useState<string>("PENDING");

  const [selectedApp, setSelectedApp] = React.useState<CreatorApplication | null>(null);
  const [isReviewOpen, setIsReviewOpen] = React.useState(false);
  const [reviewNotes, setReviewNotes] = React.useState("");
  const [modalError, setModalError] = React.useState<string | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["admin-applications", page, statusFilter],
    queryFn: () =>
      api.admin.getApplications({
        page,
        size: 20,
        status: statusFilter || undefined,
      }),
  });

  const reviewMutation = useMutation({
    mutationFn: ({ appId, status, notes }: { appId: string; status: "APPROVED" | "REJECTED"; notes?: string }) =>
      api.admin.reviewApplication(appId, status, notes),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-applications"] });
      queryClient.invalidateQueries({ queryKey: ["admin-dashboard"] });
      setIsReviewOpen(false);
      setReviewNotes("");
      setModalError(null);
    },
    onError: (err: Error) => {
      setModalError(err?.message || "Failed to submit review");
    },
  });

  const columns: ColumnDef<CreatorApplication>[] = [
    {
      accessorKey: "artist_name",
      header: "Artist Project",
      cell: ({ row }) => {
        const app = row.original;
        return (
          <div>
            <div className="font-semibold text-slate-100">{app.artist_name}</div>
            <div className="text-xs text-slate-400">
              {app.user_email || app.user_name || "Applicant"}
            </div>
          </div>
        );
      },
    },
    {
      accessorKey: "genres",
      header: "Musical Genres",
      cell: ({ row }) => (
        <span className="text-xs text-slate-300">
          {row.original.genres || "Unspecified"}
        </span>
      ),
    },
    {
      accessorKey: "portfolio_url",
      header: "Sample Work",
      cell: ({ row }) => {
        const url = row.original.portfolio_url;
        if (!url) return <span className="text-xs text-slate-500">—</span>;
        return (
          <a
            href={url}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 text-xs text-purple-400 hover:text-purple-300 hover:underline"
          >
            <span>Preview Portfolio</span>
            <ExternalLink className="h-3 w-3" />
          </a>
        );
      },
    },
    {
      accessorKey: "status",
      header: "Review Status",
      cell: ({ row }) => <StatusBadge status={row.original.status} />,
    },
    {
      accessorKey: "created_at",
      header: "Submitted",
      cell: ({ row }) => formatDate(row.original.created_at),
    },
    {
      id: "actions",
      header: "Action",
      cell: ({ row }) => {
        const app = row.original;
        return (
          <Button
            variant="outline"
            size="sm"
            onClick={() => {
              setSelectedApp(app);
              setReviewNotes(app.review_notes || "");
              setModalError(null);
              setIsReviewOpen(true);
            }}
          >
            {app.status === "PENDING" ? "Review" : "View"}
          </Button>
        );
      },
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-bold tracking-tight text-white">
          Creator Applications Queue
        </h1>
        <p className="text-xs text-slate-400 mt-1">
          Review submissions from listeners wanting to join the creator program
        </p>
      </div>

      <div className="flex items-center gap-3">
        <select
          value={statusFilter}
          onChange={(e) => {
            setStatusFilter(e.target.value);
            setPage(1);
          }}
          className="h-9.5 rounded-lg border border-slate-700/80 bg-slate-900/90 px-3 text-xs text-slate-200 focus:outline-none focus:border-purple-500"
        >
          <option value="">All Statuses</option>
          <option value="PENDING">Pending Review</option>
          <option value="APPROVED">Approved</option>
          <option value="REJECTED">Rejected</option>
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

      {/* Review Dialog */}
      <Dialog
        open={isReviewOpen}
        onOpenChange={setIsReviewOpen}
        title={`Application: ${selectedApp?.artist_name}`}
        description={`Submitted by ${selectedApp?.user_email || "Applicant"}`}
        footer={
          selectedApp?.status === "PENDING" ? (
            <>
              <Button
                variant="danger"
                size="sm"
                isLoading={reviewMutation.isPending}
                onClick={() => {
                  if (!selectedApp) return;
                  reviewMutation.mutate({
                    appId: selectedApp.id,
                    status: "REJECTED",
                    notes: reviewNotes,
                  });
                }}
              >
                <X className="h-3.5 w-3.5 mr-1" />
                Reject
              </Button>
              <Button
                variant="primary"
                size="sm"
                isLoading={reviewMutation.isPending}
                onClick={() => {
                  if (!selectedApp) return;
                  reviewMutation.mutate({
                    appId: selectedApp.id,
                    status: "APPROVED",
                    notes: reviewNotes,
                  });
                }}
              >
                <Check className="h-3.5 w-3.5 mr-1" />
                Approve & Promote
              </Button>
            </>
          ) : (
            <Button
              variant="secondary"
              size="sm"
              onClick={() => setIsReviewOpen(false)}
            >
              Close
            </Button>
          )
        }
      >
        <div className="space-y-4">
          {modalError && (
            <div className="p-2.5 rounded-lg bg-rose-950/50 border border-rose-800 text-xs text-rose-300">
              {modalError}
            </div>
          )}

          <div className="rounded-lg border border-slate-800 bg-slate-950 p-4 space-y-3 text-xs">
            <div>
              <span className="text-slate-500 block">Artist Bio / Description</span>
              <p className="text-slate-200 mt-1">
                {selectedApp?.bio || "No artist biography provided."}
              </p>
            </div>
            <div>
              <span className="text-slate-500 block">Genres</span>
              <p className="text-slate-200 mt-0.5">
                {selectedApp?.genres || "Unspecified"}
              </p>
            </div>
            {selectedApp?.portfolio_url && (
              <div>
                <span className="text-slate-500 block">External Link</span>
                <a
                  href={selectedApp.portfolio_url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-purple-400 hover:underline flex items-center gap-1 mt-0.5"
                >
                  {selectedApp.portfolio_url}
                  <ExternalLink className="h-3 w-3" />
                </a>
              </div>
            )}
          </div>

          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              Reviewer Notes
            </label>
            <textarea
              rows={3}
              placeholder="Add internal feedback or justification..."
              value={reviewNotes}
              disabled={selectedApp?.status !== "PENDING"}
              onChange={(e) => setReviewNotes(e.target.value)}
              className="w-full rounded-lg border border-slate-700 bg-slate-900 p-2.5 text-xs text-slate-200 placeholder:text-slate-500 focus:outline-none focus:border-purple-500 disabled:opacity-50"
            />
          </div>
        </div>
      </Dialog>
    </div>
  );
}
