"use client";

import * as React from "react";
import Link from "next/link";
import { useQuery } from "@tanstack/react-query";
import {
  BarChart3,
  CheckCircle,
  Clock,
  Headphones,
  Heart,
  ListMusic,
  Music2,
  Play,
  PlusCircle,
  RefreshCw,
  Sparkles,
} from "lucide-react";
import { StatCard } from "@/components/ui/stat-card";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge, StatusBadge } from "@/components/ui/badge";
import { api } from "@/lib/api/client";
import { formatDate, formatDuration, formatNumber } from "@/lib/utils";

export default function CreatorStudioDashboardPage() {
  const { data: stats, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["studio-dashboard"],
    queryFn: () => api.studio.getDashboard(),
  });

  return (
    <div className="space-y-6">
      {/* Welcome Banner */}
      <div className="rounded-2xl border border-purple-800/40 bg-gradient-to-r from-purple-950/40 via-indigo-950/20 to-slate-900/60 p-6 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Sparkles className="h-4 w-4 text-purple-400" />
            <span className="text-xs font-semibold uppercase tracking-wider text-purple-400">
              Creator Studio
            </span>
          </div>
          <h1 className="text-2xl font-bold tracking-tight text-white">
            Welcome back to your Artist Hub
          </h1>
          <p className="text-xs text-slate-400 mt-1">
            Manage your audio releases, monitor audience engagement, and inspect playback performance
          </p>
        </div>

        <div className="flex items-center gap-3">
          <Link href="/studio/upload">
            <Button variant="primary" size="sm">
              <PlusCircle className="h-4 w-4 mr-1.5" />
              Upload Track
            </Button>
          </Link>
          <Link href="/studio/analytics">
            <Button variant="outline" size="sm">
              <BarChart3 className="h-4 w-4 mr-1.5 text-purple-400" />
              Analytics
            </Button>
          </Link>
        </div>
      </div>

      {/* KPI Cards Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          title="Total Streams"
          value={stats?.total_plays ?? 0}
          subtitle="All-time listener plays"
          icon={<Play className="h-4 w-4" />}
        />
        <StatCard
          title="Published Tracks"
          value={stats?.published_tracks ?? 0}
          subtitle={`${stats?.processing_tracks ?? 0} processing in background`}
          icon={<ListMusic className="h-4 w-4" />}
        />
        <StatCard
          title="Total Followers"
          value={stats?.follower_count ?? 0}
          subtitle="Audience subscribing to your profile"
          icon={<Headphones className="h-4 w-4" />}
        />
        <StatCard
          title="Total Favorites"
          value={stats?.total_likes ?? 0}
          subtitle="Listener track likes"
          icon={<Heart className="h-4 w-4" />}
        />
      </div>

      {/* Content Split: Top Tracks & Recent Uploads */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Top Performing Tracks */}
        <Card>
          <CardHeader>
            <CardTitle>Top Performing Tracks</CardTitle>
            <CardDescription>
              Your most streamed tracks ranked by listener play count
            </CardDescription>
          </CardHeader>
          <CardContent>
            {stats?.top_tracks?.length ? (
              <div className="divide-y divide-slate-800/80">
                {stats.top_tracks.map((track, i) => (
                  <div
                    key={track.id}
                    className="py-3 flex items-center justify-between gap-4"
                  >
                    <div className="flex items-center gap-3">
                      <span className="font-bold text-sm text-slate-500 w-4">
                        {i + 1}
                      </span>
                      <div className="h-9 w-9 rounded-lg bg-slate-800 flex items-center justify-center text-slate-300">
                        <Music2 className="h-4 w-4" />
                      </div>
                      <div>
                        <div className="font-semibold text-slate-100 text-sm">
                          {track.title}
                        </div>
                        <div className="text-xs text-slate-400">
                          {track.genre || "Unspecified"} • {formatDuration(track.duration_seconds)}
                        </div>
                      </div>
                    </div>

                    <div className="text-right">
                      <div className="font-bold text-sm text-purple-300">
                        {formatNumber(track.play_count)} plays
                      </div>
                      <div className="text-[11px] text-slate-500">
                        {formatNumber(track.likes_count)} likes
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-xs text-slate-500 py-6 text-center">
                No published tracks yet. Upload your first release to see metrics!
              </p>
            )}
          </CardContent>
        </Card>

        {/* Recent Uploads */}
        <Card>
          <CardHeader>
            <CardTitle>Recent Releases</CardTitle>
            <CardDescription>
              Latest uploads and their current transcoding state
            </CardDescription>
          </CardHeader>
          <CardContent>
            {stats?.recent_uploads?.length ? (
              <div className="divide-y divide-slate-800/80">
                {stats.recent_uploads.map((track) => (
                  <div
                    key={track.id}
                    className="py-3 flex items-center justify-between gap-4"
                  >
                    <div>
                      <div className="font-semibold text-slate-100 text-sm">
                        {track.title}
                      </div>
                      <div className="text-xs text-slate-400 mt-0.5">
                        Uploaded on {formatDate(track.created_at)}
                      </div>
                    </div>

                    <div className="flex items-center gap-3">
                      <StatusBadge status={track.status} />
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-xs text-slate-500 py-6 text-center">
                No recent uploads.
              </p>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
