"use client";

import * as React from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { ColumnDef } from "@tanstack/react-table";
import {
  Activity,
  CheckCircle2,
  Database,
  HardDrive,
  Layers,
  RefreshCw,
  Server,
  XCircle,
  Zap,
} from "lucide-react";
import { DataTable } from "@/components/ui/data-table";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge, StatusBadge } from "@/components/ui/badge";
import { api } from "@/lib/api/client";
import { formatDateTime } from "@/lib/utils";
import { ProcessingJobItem, SystemHealthStatus } from "@/types";

export default function AdminOperationsPage() {
  const queryClient = useQueryClient();
  const [page, setPage] = React.useState(1);
  const [statusFilter, setStatusFilter] = React.useState<string>("");

  const {
    data: health,
    isLoading: isHealthLoading,
    refetch: refetchHealth,
    isFetching: isHealthFetching,
  } = useQuery({
    queryKey: ["operations-health"],
    queryFn: () => api.admin.getOperationsHealth(),
    refetchInterval: 15000, // Poll every 15s
  });

  const { data: jobsData, isLoading: isJobsLoading } = useQuery({
    queryKey: ["processing-jobs", page, statusFilter],
    queryFn: () =>
      api.admin.getProcessingJobs({
        page,
        size: 20,
        status: statusFilter || undefined,
      }),
  });

  const retryMutation = useMutation({
    mutationFn: (trackId: string) => api.admin.retryTrack(trackId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["processing-jobs"] });
    },
  });

  const columns: ColumnDef<ProcessingJobItem>[] = [
    {
      accessorKey: "track_id",
      header: "Media Track",
      cell: ({ row }) => {
        const j = row.original;
        return (
          <div>
            <div className="font-semibold text-slate-100">
              {j.track_title || `Track ${j.track_id.slice(0, 8)}`}
            </div>
            <div className="font-mono text-xs text-slate-500">
              {j.track_id}
            </div>
          </div>
        );
      },
    },
    {
      accessorKey: "job_type",
      header: "Pipeline Stage",
      cell: ({ row }) => (
        <Badge variant="purple">{row.original.job_type}</Badge>
      ),
    },
    {
      accessorKey: "status",
      header: "Status",
      cell: ({ row }) => <StatusBadge status={row.original.status} />,
    },
    {
      accessorKey: "attempts",
      header: "Attempts",
      cell: ({ row }) => row.original.attempts,
    },
    {
      accessorKey: "error_message",
      header: "Diagnostics / Failure Log",
      cell: ({ row }) => {
        const err = row.original.error_message;
        if (!err) return <span className="text-xs text-slate-500">—</span>;
        return (
          <span className="text-xs text-rose-300 font-mono truncate block max-w-sm" title={err}>
            {err}
          </span>
        );
      },
    },
    {
      accessorKey: "created_at",
      header: "Triggered",
      cell: ({ row }) => formatDateTime(row.original.created_at),
    },
    {
      id: "actions",
      header: "Action",
      cell: ({ row }) => {
        const j = row.original;
        if (j.status !== "FAILED") return null;
        return (
          <Button
            variant="outline"
            size="sm"
            onClick={() => retryMutation.mutate(j.track_id)}
            isLoading={retryMutation.isPending}
          >
            <RefreshCw className="h-3 w-3 mr-1 text-purple-400" />
            Retry
          </Button>
        );
      },
    },
  ];

  const services = [
    {
      name: "PostgreSQL Database",
      status: health?.database,
      description: "Primary relational store & subscriptions",
      icon: <Database className="h-5 w-5" />,
    },
    {
      name: "Redis Cache & Broker",
      status: health?.redis,
      description: "Entitlements cache & rate limiting",
      icon: <Zap className="h-5 w-5" />,
    },
    {
      name: "Celery Task Workers",
      status: health?.celery_broker,
      description: "Background FFmpeg audio transcoding",
      icon: <Server className="h-5 w-5" />,
    },
    {
      name: "MinIO / S3 Object Storage",
      status: health?.storage,
      description: "Master audio and HLS rendition storage",
      icon: <HardDrive className="h-5 w-5" />,
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold tracking-tight text-white">
            Operations & Infrastructure Health
          </h1>
          <p className="text-xs text-slate-400 mt-1">
            Real-time dependency health checks and media processing pipeline queue
          </p>
        </div>
        <Button
          variant="outline"
          size="sm"
          onClick={() => refetchHealth()}
          isLoading={isHealthFetching}
        >
          <RefreshCw className="h-3.5 w-3.5" />
          <span>Probe Infrastructure</span>
        </Button>
      </div>

      {/* Services Health Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {services.map((srv) => (
          <div
            key={srv.name}
            className="rounded-xl border border-slate-800 bg-slate-900/60 p-5 shadow-sm"
          >
            <div className="flex items-center justify-between mb-3">
              <div className="p-2 rounded-lg bg-slate-800 text-purple-400">
                {srv.icon}
              </div>
              <Badge variant={srv.status ? "success" : "danger"}>
                {srv.status ? "HEALTHY" : "DEGRADED"}
              </Badge>
            </div>
            <div className="text-sm font-semibold text-slate-100">{srv.name}</div>
            <p className="text-xs text-slate-400 mt-1">{srv.description}</p>
          </div>
        ))}
      </div>

      {/* Processing Pipeline Section */}
      <Card>
        <CardHeader>
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <CardTitle>Audio Processing & Transcoding Queue</CardTitle>
              <CardDescription>
                FFmpeg transcode jobs generating 128kbps, 256kbps, and 320kbps MP3/AAC renditions
              </CardDescription>
            </div>
            <select
              value={statusFilter}
              onChange={(e) => {
                setStatusFilter(e.target.value);
                setPage(1);
              }}
              className="h-8 rounded-lg border border-slate-700 bg-slate-900 px-2.5 text-xs text-slate-200 focus:outline-none focus:border-purple-500"
            >
              <option value="">All Job Statuses</option>
              <option value="PROCESSING">Processing</option>
              <option value="FAILED">Failed Jobs</option>
              <option value="COMPLETED">Completed</option>
              <option value="PENDING">Pending</option>
            </select>
          </div>
        </CardHeader>
        <CardContent>
          <DataTable
            columns={columns}
            data={jobsData?.items ?? []}
            isLoading={isJobsLoading}
            page={page}
            totalPages={jobsData?.total_pages ?? 1}
            total={jobsData?.total}
            onPageChange={(newPage) => setPage(newPage)}
          />
        </CardContent>
      </Card>
    </div>
  );
}
