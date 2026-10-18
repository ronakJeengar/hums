"use client";

import * as React from "react";
import { useQuery } from "@tanstack/react-query";
import { ColumnDef } from "@tanstack/react-table";
import { FileText, Search, ShieldCheck } from "lucide-react";
import { DataTable } from "@/components/ui/data-table";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { api } from "@/lib/api/client";
import { formatDateTime } from "@/lib/utils";
import { AdminAuditLog } from "@/types";

export default function AdminAuditLogsPage() {
  const [page, setPage] = React.useState(1);
  const [search, setSearch] = React.useState("");
  const [targetType, setTargetType] = React.useState<string>("");

  const { data, isLoading } = useQuery({
    queryKey: ["admin-audit-logs", page, search, targetType],
    queryFn: () =>
      api.admin.getAuditLogs({
        page,
        size: 25,
        search: search || undefined,
        target_type: targetType || undefined,
      }),
  });

  const columns: ColumnDef<AdminAuditLog>[] = [
    {
      accessorKey: "action",
      header: "Action",
      cell: ({ row }) => (
        <Badge variant="purple" className="font-mono text-[10px]">
          {row.original.action}
        </Badge>
      ),
    },
    {
      accessorKey: "actor_email",
      header: "Actor (Staff)",
      cell: ({ row }) => (
        <span className="text-xs font-medium text-slate-200">
          {row.original.actor_email}
        </span>
      ),
    },
    {
      accessorKey: "target_type",
      header: "Target Entity",
      cell: ({ row }) => {
        const l = row.original;
        return (
          <div>
            <span className="text-xs font-semibold text-slate-300 capitalize">
              {l.target_type}
            </span>
            <div className="font-mono text-[11px] text-slate-500 truncate max-w-[120px]">
              {l.target_id}
            </div>
          </div>
        );
      },
    },
    {
      accessorKey: "reason",
      header: "Context / Reason",
      cell: ({ row }) => (
        <span className="text-xs text-slate-300">
          {row.original.reason || "—"}
        </span>
      ),
    },
    {
      accessorKey: "ip_address",
      header: "Client IP",
      cell: ({ row }) => (
        <span className="font-mono text-xs text-slate-400">
          {row.original.ip_address || "127.0.0.1"}
        </span>
      ),
    },
    {
      accessorKey: "created_at",
      header: "Timestamp",
      cell: ({ row }) => (
        <span className="text-xs text-slate-400">
          {formatDateTime(row.original.created_at)}
        </span>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-bold tracking-tight text-white">
          Administrative Audit Logs
        </h1>
        <p className="text-xs text-slate-400 mt-1">
          Immutable event log tracking all staff actions, privilege grants, and moderation decisions
        </p>
      </div>

      <div className="flex flex-wrap items-center gap-3">
        <div className="w-full sm:w-64">
          <Input
            placeholder="Search action or email..."
            icon={<Search className="h-4 w-4" />}
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPage(1);
            }}
          />
        </div>

        <select
          value={targetType}
          onChange={(e) => {
            setTargetType(e.target.value);
            setPage(1);
          }}
          className="h-9.5 rounded-lg border border-slate-700/80 bg-slate-900/90 px-3 text-xs text-slate-200 focus:outline-none focus:border-purple-500"
        >
          <option value="">All Entity Types</option>
          <option value="user">User Account</option>
          <option value="track">Track / Audio</option>
          <option value="creator">Creator Profile</option>
          <option value="application">Creator Application</option>
          <option value="report">Violation Report</option>
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
    </div>
  );
}
