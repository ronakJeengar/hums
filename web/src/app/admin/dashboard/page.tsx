"use client";

import * as React from "react";
import { useQuery } from "@tanstack/react-query";
import {
  AlertTriangle,
  CheckCircle2,
  Clock,
  CreditCard,
  FileCheck2,
  Headphones,
  ListMusic,
  RefreshCw,
  ShieldAlert,
  Users,
} from "lucide-react";
import { StatCard } from "@/components/ui/stat-card";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { api } from "@/lib/api/client";
import { formatDateTime } from "@/lib/utils";

export default function AdminDashboardPage() {
  const { data: stats, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["admin-dashboard"],
    queryFn: () => api.admin.getDashboard(),
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold tracking-tight text-white">
            Platform Overview
          </h1>
          <p className="text-xs text-slate-400 mt-1">
            Real-time system health, user metrics, and pending moderation queues
          </p>
        </div>
        <Button
          variant="outline"
          size="sm"
          onClick={() => refetch()}
          isLoading={isFetching}
          className="self-start sm:self-auto"
        >
          <RefreshCw className="h-3.5 w-3.5" />
          <span>Refresh Metrics</span>
        </Button>
      </div>

      {/* KPI Cards Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          title="Total Users"
          value={stats?.total_users ?? 0}
          subtitle={`${stats?.active_users_30d ?? 0} active in last 30d`}
          icon={<Users className="h-4 w-4" />}
        />
        <StatCard
          title="Total Creators"
          value={stats?.total_creators ?? 0}
          subtitle="Verified & active artists"
          icon={<Headphones className="h-4 w-4" />}
        />
        <StatCard
          title="Published Tracks"
          value={stats?.published_tracks ?? 0}
          subtitle={`${stats?.failed_uploads ?? 0} failed transcodes`}
          icon={<ListMusic className="h-4 w-4" />}
        />
        <StatCard
          title="Active Subscriptions"
          value={stats?.subscriptions_summary?.total_active ?? 0}
          subtitle="Verified paying subscribers"
          icon={<CreditCard className="h-4 w-4" />}
        />
      </div>

      {/* Queue Alerts Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div className="rounded-xl border border-amber-900/40 bg-amber-950/20 p-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-lg bg-amber-900/30 text-amber-400">
              <FileCheck2 className="h-5 w-5" />
            </div>
            <div>
              <div className="text-sm font-semibold text-amber-200">
                Pending Creator Applications
              </div>
              <div className="text-xs text-amber-400/80">
                Listeners waiting for artist approval
              </div>
            </div>
          </div>
          <span className="text-2xl font-bold text-amber-300">
            {stats?.pending_applications ?? 0}
          </span>
        </div>

        <div className="rounded-xl border border-rose-900/40 bg-rose-950/20 p-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-lg bg-rose-900/30 text-rose-400">
              <ShieldAlert className="h-5 w-5" />
            </div>
            <div>
              <div className="text-sm font-semibold text-rose-200">
                Content Violation Reports
              </div>
              <div className="text-xs text-rose-400/80">
                Reported tracks, creators, and profiles
              </div>
            </div>
          </div>
          <span className="text-2xl font-bold text-rose-300">
            {stats?.pending_reports ?? 0}
          </span>
        </div>
      </div>

      {/* Audit Activity & Subscription Breakdown */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Recent Audit Logs (2 cols) */}
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>Recent Administrative Activity</CardTitle>
            <CardDescription>
              Immutable audit log of staff actions and moderation decisions
            </CardDescription>
          </CardHeader>
          <CardContent>
            {stats?.recent_activity?.length ? (
              <div className="divide-y divide-slate-800/80">
                {stats.recent_activity.map((log) => (
                  <div
                    key={log.id}
                    className="py-3 flex items-start justify-between gap-4"
                  >
                    <div>
                      <div className="flex items-center gap-2">
                        <Badge variant="purple" className="text-[10px]">
                          {log.action}
                        </Badge>
                        <span className="text-xs text-slate-300 font-medium">
                          {log.actor_email}
                        </span>
                      </div>
                      <p className="text-xs text-slate-400 mt-1">
                        Target: <span className="text-slate-300">{log.target_type}</span>{" "}
                        ({log.target_id.slice(0, 8)}...)
                        {log.reason && ` — Reason: "${log.reason}"`}
                      </p>
                    </div>
                    <span className="text-[11px] text-slate-500 whitespace-nowrap">
                      {formatDateTime(log.created_at)}
                    </span>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-xs text-slate-500 py-6 text-center">
                No recent administrative activity recorded.
              </p>
            )}
          </CardContent>
        </Card>

        {/* Plan Breakdown */}
        <Card>
          <CardHeader>
            <CardTitle>Subscription Catalog Status</CardTitle>
            <CardDescription>
              Distribution of active commercial tiers
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="p-3 rounded-lg bg-slate-950/60 border border-slate-800 flex justify-between items-center">
              <div>
                <span className="text-xs font-semibold text-slate-200 block">
                  Free Tier Listeners
                </span>
                <span className="text-[11px] text-slate-400">
                  Standard 128kbps, ad-supported
                </span>
              </div>
              <Badge variant="outline">Default</Badge>
            </div>

            <div className="p-3 rounded-lg bg-purple-950/30 border border-purple-800/40 flex justify-between items-center">
              <div>
                <span className="text-xs font-semibold text-purple-200 block">
                  Premium Monthly / Yearly
                </span>
                <span className="text-[11px] text-purple-300/80">
                  Lossless 320kbps, downloads, offline
                </span>
              </div>
              <span className="text-base font-bold text-purple-300">
                {stats?.subscriptions_summary?.total_active ?? 0}
              </span>
            </div>

            <div className="pt-2 text-xs text-slate-500">
              Subscription decisions, entitlements, and receipts are verified
              authoritatively server-side via PostgreSQL.
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
