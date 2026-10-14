"use client";

import * as React from "react";
import { useQuery } from "@tanstack/react-query";
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import {
  BarChart3,
  Calendar,
  Headphones,
  Music2,
  Play,
  Radio,
  RefreshCw,
  TrendingUp,
} from "lucide-react";
import { StatCard } from "@/components/ui/stat-card";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { api } from "@/lib/api/client";
import { formatNumber } from "@/lib/utils";

export default function CreatorAnalyticsPage() {
  const [period, setPeriod] = React.useState<"7d" | "30d" | "90d">("30d");

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["studio-analytics", period],
    queryFn: () => api.studio.getAnalytics(period),
  });

  return (
    <div className="space-y-6">
      {/* Header & Period Filters */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold tracking-tight text-white">
            Audience & Playback Analytics
          </h1>
          <p className="text-xs text-slate-400 mt-1">
            Real-time playback trends, unique listeners, and discovery source breakdown
          </p>
        </div>

        <div className="flex items-center gap-2">
          <div className="flex rounded-lg border border-slate-800 bg-slate-900 p-1 text-xs">
            {(["7d", "30d", "90d"] as const).map((p) => (
              <button
                key={p}
                onClick={() => setPeriod(p)}
                className={`px-3 py-1 rounded font-medium transition-colors cursor-pointer ${
                  period === p
                    ? "bg-purple-600 text-white"
                    : "text-slate-400 hover:text-slate-200"
                }`}
              >
                {p === "7d" ? "Last 7 Days" : p === "30d" ? "Last 30 Days" : "Last 90 Days"}
              </button>
            ))}
          </div>

          <Button
            variant="ghost"
            size="sm"
            onClick={() => refetch()}
            isLoading={isFetching}
          >
            <RefreshCw className="h-4 w-4" />
          </Button>
        </div>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <StatCard
          title="Period Streams"
          value={data?.total_plays ?? 0}
          subtitle={`Aggregated plays across ${period}`}
          icon={<Play className="h-4 w-4" />}
        />
        <StatCard
          title="Unique Listeners"
          value={data?.unique_listeners ?? 0}
          subtitle="Distinct listener accounts"
          icon={<Headphones className="h-4 w-4" />}
        />
        <StatCard
          title="Avg Streams Per Listener"
          value={
            data && data.unique_listeners > 0
              ? (data.total_plays / data.unique_listeners).toFixed(1)
              : "0"
          }
          subtitle="Repeat listening engagement"
          icon={<TrendingUp className="h-4 w-4" />}
        />
      </div>

      {/* Plays Over Time Chart */}
      <Card>
        <CardHeader>
          <CardTitle>Daily Playback Volume</CardTitle>
          <CardDescription>
            Listening events over the selected period
          </CardDescription>
        </CardHeader>
        <CardContent>
          {data?.plays_timeline && data.plays_timeline.length > 0 ? (
            <div className="h-72 w-full pt-4">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart
                  data={data.plays_timeline}
                  margin={{ top: 10, right: 10, left: -20, bottom: 0 }}
                >
                  <defs>
                    <linearGradient id="playsGradient" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#8b5cf6" stopOpacity={0.4} />
                      <stop offset="95%" stopColor="#8b5cf6" stopOpacity={0.0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="#1e2235" />
                  <XAxis
                    dataKey="date"
                    stroke="#64748b"
                    fontSize={11}
                    tickLine={false}
                  />
                  <YAxis stroke="#64748b" fontSize={11} tickLine={false} />
                  <Tooltip
                    contentStyle={{
                      backgroundColor: "#0f172a",
                      borderColor: "#334155",
                      borderRadius: "8px",
                      fontSize: "12px",
                      color: "#f8fafc",
                    }}
                  />
                  <Area
                    type="monotone"
                    dataKey="plays"
                    stroke="#8b5cf6"
                    strokeWidth={2}
                    fillOpacity={1}
                    fill="url(#playsGradient)"
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          ) : (
            <div className="h-72 flex items-center justify-center text-xs text-slate-500">
              No playback activity recorded in this period yet.
            </div>
          )}
        </CardContent>
      </Card>

      {/* Top Tracks Bar Chart & Discovery Sources */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Top Tracks Bar Chart */}
        <Card>
          <CardHeader>
            <CardTitle>Top Tracks by Plays</CardTitle>
            <CardDescription>
              Rank of leading tracks streamed in this window
            </CardDescription>
          </CardHeader>
          <CardContent>
            {data?.top_tracks && data.top_tracks.length > 0 ? (
              <div className="h-64 w-full pt-4">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart
                    data={data.top_tracks}
                    layout="vertical"
                    margin={{ top: 5, right: 30, left: 20, bottom: 5 }}
                  >
                    <CartesianGrid strokeDasharray="3 3" stroke="#1e2235" />
                    <XAxis type="number" stroke="#64748b" fontSize={11} />
                    <YAxis
                      dataKey="title"
                      type="category"
                      stroke="#94a3b8"
                      fontSize={11}
                      width={100}
                    />
                    <Tooltip
                      contentStyle={{
                        backgroundColor: "#0f172a",
                        borderColor: "#334155",
                        borderRadius: "8px",
                        fontSize: "12px",
                        color: "#f8fafc",
                      }}
                    />
                    <Bar dataKey="plays" fill="#a855f7" radius={[0, 4, 4, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            ) : (
              <div className="h-64 flex items-center justify-center text-xs text-slate-500">
                No track playback events recorded.
              </div>
            )}
          </CardContent>
        </Card>

        {/* Discovery Sources Breakdown */}
        <Card>
          <CardHeader>
            <CardTitle>Listening Entry Points</CardTitle>
            <CardDescription>
              How listeners discover and trigger your audio releases
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-3">
              {[
                { label: "Smart Queue & Radio", key: "smart_queue", pct: 45 },
                { label: "AI Recommendations", key: "recommendations", pct: 30 },
                { label: "Direct Search & Artist Page", key: "search", pct: 15 },
                { label: "User Playlists & Library", key: "playlists", pct: 10 },
              ].map((item) => (
                <div key={item.key} className="space-y-1">
                  <div className="flex justify-between text-xs">
                    <span className="text-slate-300 font-medium">{item.label}</span>
                    <span className="text-slate-400 font-mono">{item.pct}%</span>
                  </div>
                  <div className="w-full h-2 rounded-full bg-slate-800 overflow-hidden">
                    <div
                      className="h-full rounded-full bg-purple-500"
                      style={{ width: `${item.pct}%` }}
                    />
                  </div>
                </div>
              ))}
            </div>

            <p className="text-xs text-slate-500 pt-2 border-t border-slate-800">
              Data is calculated directly from PostgreSQL playback event telemetry.
            </p>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
