"use client";

import * as React from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { ColumnDef } from "@tanstack/react-table";
import { ShieldAlert } from "lucide-react";
import { DataTable } from "@/components/ui/data-table";
import { Button } from "@/components/ui/button";
import { Badge, StatusBadge } from "@/components/ui/badge";
import { Dialog } from "@/components/ui/dialog";
import { api } from "@/lib/api/client";
import { formatDate } from "@/lib/utils";
import { ContentReport } from "@/types";

export default function AdminReportsPage() {
  const queryClient = useQueryClient();
  const [page, setPage] = React.useState(1);
  const [statusFilter, setStatusFilter] = React.useState<string>("PENDING");
  const [reasonFilter, setReasonFilter] = React.useState<string>("");

  const [selectedReport, setSelectedReport] = React.useState<ContentReport | null>(null);
  const [isResolveModalOpen, setIsResolveModalOpen] = React.useState(false);
  const [resolutionStatus, setResolutionStatus] = React.useState<"RESOLVED" | "DISMISSED" | "INVESTIGATING">("RESOLVED");
  const [actionTaken, setActionTaken] = React.useState<string>("NO_ACTION");
  const [resolutionNotes, setResolutionNotes] = React.useState<string>("");
  const [modalError, setModalError] = React.useState<string | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["admin-reports", page, statusFilter, reasonFilter],
    queryFn: () =>
      api.admin.getReports({
        page,
        size: 20,
        status: statusFilter || undefined,
        reason: reasonFilter || undefined,
      }),
  });

  const resolveMutation = useMutation({
    mutationFn: ({
      reportId,
      status,
      actionTaken,
      notes,
    }: {
      reportId: string;
      status: "RESOLVED" | "DISMISSED" | "INVESTIGATING";
      actionTaken: string;
      notes: string;
    }) =>
      api.admin.resolveReport(reportId, status, actionTaken, notes),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-reports"] });
      queryClient.invalidateQueries({ queryKey: ["admin-dashboard"] });
      setIsResolveModalOpen(false);
      setResolutionNotes("");
      setModalError(null);
    },
    onError: (err: Error) => {
      setModalError(err?.message || "Failed to resolve report");
    },
  });

  const columns: ColumnDef<ContentReport>[] = [
    {
      accessorKey: "entity_type",
      header: "Target Entity",
      cell: ({ row }) => {
        const r = row.original;
        return (
          <div>
            <div className="font-semibold text-slate-100 capitalize">
              {r.entity_type}: <span className="font-mono text-xs text-purple-400">{r.entity_id.slice(0, 8)}...</span>
            </div>
            <div className="text-xs text-slate-400">
              Reporter: {r.reporter_email || r.reporter_id.slice(0, 8)}
            </div>
          </div>
        );
      },
    },
    {
      accessorKey: "reason",
      header: "Violation Reason",
      cell: ({ row }) => (
        <Badge variant="warning">{row.original.reason}</Badge>
      ),
    },
    {
      accessorKey: "description",
      header: "Details",
      cell: ({ row }) => (
        <p className="text-xs text-slate-300 max-w-xs truncate">
          {row.original.description || "No description provided."}
        </p>
      ),
    },
    {
      accessorKey: "status",
      header: "Status",
      cell: ({ row }) => <StatusBadge status={row.original.status} />,
    },
    {
      accessorKey: "created_at",
      header: "Reported On",
      cell: ({ row }) => formatDate(row.original.created_at),
    },
    {
      id: "actions",
      header: "Actions",
      cell: ({ row }) => {
        const r = row.original;
        return (
          <Button
            variant="outline"
            size="sm"
            onClick={() => {
              setSelectedReport(r);
              setResolutionStatus("RESOLVED");
              setActionTaken(r.action_taken || "NO_ACTION");
              setResolutionNotes(r.resolution_notes || "");
              setModalError(null);
              setIsResolveModalOpen(true);
            }}
          >
            <ShieldAlert className="h-3.5 w-3.5 mr-1 text-purple-400" />
            <span>{r.status === "PENDING" ? "Resolve" : "View"}</span>
          </Button>
        );
      },
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-bold tracking-tight text-white">
          Content Violation Reports Queue
        </h1>
        <p className="text-xs text-slate-400 mt-1">
          Review community flags, investigate copyright violations, and enforce trust and safety
        </p>
      </div>

      <div className="flex flex-wrap items-center gap-3">
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
          <option value="INVESTIGATING">Under Investigation</option>
          <option value="RESOLVED">Resolved</option>
          <option value="DISMISSED">Dismissed</option>
        </select>

        <select
          value={reasonFilter}
          onChange={(e) => {
            setReasonFilter(e.target.value);
            setPage(1);
          }}
          className="h-9.5 rounded-lg border border-slate-700/80 bg-slate-900/90 px-3 text-xs text-slate-200 focus:outline-none focus:border-purple-500"
        >
          <option value="">All Reasons</option>
          <option value="COPYRIGHT">Copyright / DMCA</option>
          <option value="INAPPROPRIATE">Inappropriate Content</option>
          <option value="SPAM">Spam or Abuse</option>
          <option value="HARASSMENT">Harassment</option>
          <option value="OTHER">Other</option>
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

      {/* Resolution Dialog */}
      <Dialog
        open={isResolveModalOpen}
        onOpenChange={setIsResolveModalOpen}
        title="Resolve Content Violation Report"
        description={`Report ID: ${selectedReport?.id}`}
        footer={
          <>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setIsResolveModalOpen(false)}
            >
              Close
            </Button>
            <Button
              variant="primary"
              size="sm"
              isLoading={resolveMutation.isPending}
              onClick={() => {
                if (!selectedReport) return;
                resolveMutation.mutate({
                  reportId: selectedReport.id,
                  status: resolutionStatus,
                  actionTaken,
                  notes: resolutionNotes,
                });
              }}
            >
              Submit Decision
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

          <div className="rounded-lg border border-slate-800 bg-slate-950 p-4 space-y-2 text-xs">
            <div>
              <span className="text-slate-500 block">Reported Target</span>
              <p className="text-slate-200 font-mono">
                {selectedReport?.entity_type} / {selectedReport?.entity_id}
              </p>
            </div>
            <div>
              <span className="text-slate-500 block">Violation Claim</span>
              <p className="text-slate-200 font-semibold text-rose-300">
                {selectedReport?.reason}
              </p>
            </div>
            <div>
              <span className="text-slate-500 block">Reporter Description</span>
              <p className="text-slate-300 mt-0.5">
                {selectedReport?.description || "No description provided."}
              </p>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-medium text-slate-300 mb-1.5">
                Resolution State
              </label>
              <select
                value={resolutionStatus}
                onChange={(e) =>
                  setResolutionStatus(
                    e.target.value as "RESOLVED" | "DISMISSED" | "INVESTIGATING"
                  )
                }
                className="w-full h-10 rounded-lg border border-slate-700 bg-slate-900 px-3 text-xs text-slate-200 focus:outline-none focus:border-purple-500"
              >
                <option value="RESOLVED">RESOLVED</option>
                <option value="DISMISSED">DISMISSED (Invalid)</option>
                <option value="INVESTIGATING">INVESTIGATING</option>
              </select>
            </div>

            <div>
              <label className="block text-xs font-medium text-slate-300 mb-1.5">
                Action Taken
              </label>
              <select
                value={actionTaken}
                onChange={(e) => setActionTaken(e.target.value)}
                className="w-full h-10 rounded-lg border border-slate-700 bg-slate-900 px-3 text-xs text-slate-200 focus:outline-none focus:border-purple-500"
              >
                <option value="NO_ACTION">No Action Required</option>
                <option value="TRACK_MODERATED">Track Moderated / Taken Down</option>
                <option value="USER_WARNED">User Warned</option>
                <option value="USER_SUSPENDED">User Account Suspended</option>
              </select>
            </div>
          </div>

          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              Resolution Notes (Audit Trail)
            </label>
            <textarea
              rows={3}
              placeholder="Explain findings and justification..."
              value={resolutionNotes}
              onChange={(e) => setResolutionNotes(e.target.value)}
              className="w-full rounded-lg border border-slate-700 bg-slate-900 p-2.5 text-xs text-slate-200 placeholder:text-slate-500 focus:outline-none focus:border-purple-500"
            />
          </div>
        </div>
      </Dialog>
    </div>
  );
}
