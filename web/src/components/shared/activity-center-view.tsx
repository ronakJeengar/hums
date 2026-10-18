"use client";

import * as React from "react";
import Link from "next/link";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  Bell,
  CheckCheck,
  CheckCircle,
  AlertCircle,
  Sparkles,
  Radio,
  FileText,
  Clock,
  ExternalLink,
  Filter,
  RefreshCw,
  Sliders,
  Check,
  ChevronLeft,
  ChevronRight,
  Layers,
  Inbox,
} from "lucide-react";
import { api } from "@/lib/api/client";
import {
  NotificationItem,
  NotificationPreferences,
  NotificationPreferencesUpdate,
} from "@/types";
import { cn, formatDateTime } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

interface ActivityCenterViewProps {
  experience: "admin" | "studio";
}

function getNotificationTypeBadge(type: string) {
  switch (type) {
    case "UPLOAD_COMPLETE":
      return <Badge variant="success">Upload Ready</Badge>;
    case "TRACK_PUBLISHED":
      return <Badge variant="success">Published</Badge>;
    case "TRACK_PROCESSING_FAILED":
      return <Badge variant="danger">Processing Failed</Badge>;
    case "TRACK_MODERATED":
      return <Badge variant="purple">Moderation</Badge>;
    case "CREATOR_APPLICATION":
      return <Badge variant="info">Creator Application</Badge>;
    case "NEW_RELEASE":
      return <Badge variant="warning">New Release</Badge>;
    case "PLAYLIST_UPDATE":
      return <Badge variant="outline">Playlist</Badge>;
    default:
      return <Badge variant="outline">{type}</Badge>;
  }
}

function getNotificationIcon(type: string) {
  switch (type) {
    case "UPLOAD_COMPLETE":
    case "TRACK_PUBLISHED":
      return <Sparkles className="h-5 w-5 text-emerald-400" />;
    case "TRACK_PROCESSING_FAILED":
      return <AlertCircle className="h-5 w-5 text-rose-400" />;
    case "TRACK_MODERATED":
      return <FileText className="h-5 w-5 text-purple-400" />;
    case "CREATOR_APPLICATION":
      return <CheckCircle className="h-5 w-5 text-indigo-400" />;
    case "NEW_RELEASE":
    case "PLAYLIST_UPDATE":
      return <Radio className="h-5 w-5 text-cyan-400" />;
    default:
      return <Bell className="h-5 w-5 text-slate-400" />;
  }
}

export function ActivityCenterView({ experience }: ActivityCenterViewProps) {
  const queryClient = useQueryClient();
  const [activeTab, setActiveTab] = React.useState<"all" | "unread" | "preferences">("all");
  const [typeFilter, setTypeFilter] = React.useState<string>("");
  const [page, setPage] = React.useState(1);
  const pageSize = 15;

  const skip = (page - 1) * pageSize;
  const isReadFilter = activeTab === "unread" ? false : undefined;

  // Unread badge count query
  const { data: unreadData } = useQuery({
    queryKey: ["notifications", "unread-count"],
    queryFn: () => api.notifications.getUnreadCount(),
    refetchInterval: 15000,
  });

  // Notifications query
  const {
    data: listData,
    isLoading: isListLoading,
    isFetching,
    refetch,
  } = useQuery({
    queryKey: ["notifications", "list", skip, pageSize, isReadFilter, typeFilter],
    queryFn: () =>
      api.notifications.list({
        skip,
        limit: pageSize,
        is_read: isReadFilter,
        type: typeFilter || undefined,
      }),
  });

  // Preferences query
  const { data: preferencesData, isLoading: isPrefsLoading } = useQuery({
    queryKey: ["notifications", "preferences"],
    queryFn: () => api.notifications.getPreferences(),
  });

  // Mark single as read mutation
  const markReadMutation = useMutation({
    mutationFn: (id: string) => api.notifications.markAsRead(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["notifications"] });
    },
  });

  // Mark all as read mutation
  const markAllMutation = useMutation({
    mutationFn: () => api.notifications.markAllAsRead(),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["notifications"] });
    },
  });

  // Update preferences mutation
  const updatePrefsMutation = useMutation({
    mutationFn: (data: NotificationPreferencesUpdate) =>
      api.notifications.updatePreferences(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["notifications", "preferences"] });
    },
  });

  const unreadCount = unreadData?.unread_count ?? 0;
  const notifications = listData?.items ?? [];
  const totalCount = listData?.total ?? 0;
  const totalPages = Math.ceil(totalCount / pageSize) || 1;

  const handleTogglePreference = (key: keyof NotificationPreferences, currentValue: boolean) => {
    updatePrefsMutation.mutate({ [key]: !currentValue });
  };

  const getTargetResourceLink = (item: NotificationItem) => {
    if (!item.data || typeof item.data !== "object") return null;
    const dataObj = item.data as Record<string, unknown>;

    if (dataObj.track_id) {
      const trackId = String(dataObj.track_id);
      return {
        href: experience === "admin" ? `/admin/tracks/${trackId}` : `/studio/tracks/${trackId}`,
        label: experience === "admin" ? "Inspect Track in Admin" : "Manage Track in Studio",
      };
    }
    if (dataObj.application_id && experience === "admin") {
      return {
        href: "/admin/applications",
        label: "Review Application Queue",
      };
    }
    return null;
  };

  return (
    <div className="space-y-6">
      {/* Top Banner / Breadcrumb */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-2xl font-bold tracking-tight text-white">Activity Center</h1>
            <Badge variant="purple" className="text-xs capitalize">
              {experience === "admin" ? "Admin Ops" : "Creator Studio"}
            </Badge>
          </div>
          <p className="text-sm text-slate-400 mt-1">
            Real-time notifications, event audits, processing alerts, and notification preferences.
          </p>
        </div>

        <div className="flex items-center gap-2.5">
          <Button
            variant="outline"
            size="sm"
            onClick={() => refetch()}
            disabled={isFetching}
            className="border-slate-800 text-slate-300 hover:text-white"
          >
            <RefreshCw className={cn("h-4 w-4 mr-1.5", isFetching && "animate-spin")} />
            <span>Refresh</span>
          </Button>

          {unreadCount > 0 && (
            <Button
              variant="primary"
              size="sm"
              onClick={() => markAllMutation.mutate()}
              isLoading={markAllMutation.isPending}
            >
              <CheckCheck className="h-4 w-4 mr-1.5" />
              <span>Mark all as read ({unreadCount})</span>
            </Button>
          )}
        </div>
      </div>

      {/* Tabs and Filtering Bar */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-slate-800 pb-3">
        {/* Navigation Tabs */}
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => {
              setActiveTab("all");
              setPage(1);
            }}
            className={cn(
              "px-3.5 py-1.5 rounded-lg text-xs font-medium transition-colors flex items-center gap-2",
              activeTab === "all"
                ? "bg-purple-600 text-white shadow-md shadow-purple-900/30"
                : "text-slate-400 hover:text-slate-200 hover:bg-slate-800/60"
            )}
          >
            <Layers className="h-3.5 w-3.5" />
            <span>All Notifications</span>
            {totalCount > 0 && activeTab === "all" && (
              <span className="rounded-full bg-purple-700/60 px-1.5 py-0.2 text-[10px]">
                {totalCount}
              </span>
            )}
          </button>

          <button
            type="button"
            onClick={() => {
              setActiveTab("unread");
              setPage(1);
            }}
            className={cn(
              "px-3.5 py-1.5 rounded-lg text-xs font-medium transition-colors flex items-center gap-2",
              activeTab === "unread"
                ? "bg-purple-600 text-white shadow-md shadow-purple-900/30"
                : "text-slate-400 hover:text-slate-200 hover:bg-slate-800/60"
            )}
          >
            <Bell className="h-3.5 w-3.5" />
            <span>Unread Only</span>
            {unreadCount > 0 && (
              <span className="rounded-full bg-rose-500 px-1.5 py-0.2 text-[10px] text-white font-bold">
                {unreadCount}
              </span>
            )}
          </button>

          <button
            type="button"
            onClick={() => setActiveTab("preferences")}
            className={cn(
              "px-3.5 py-1.5 rounded-lg text-xs font-medium transition-colors flex items-center gap-2",
              activeTab === "preferences"
                ? "bg-purple-600 text-white shadow-md shadow-purple-900/30"
                : "text-slate-400 hover:text-slate-200 hover:bg-slate-800/60"
            )}
          >
            <Sliders className="h-3.5 w-3.5" />
            <span>Notification Settings</span>
          </button>
        </div>

        {/* Filter by Type (only on notification list tabs) */}
        {activeTab !== "preferences" && (
          <div className="flex items-center gap-2">
            <Filter className="h-3.5 w-3.5 text-slate-500" />
            <select
              value={typeFilter}
              onChange={(e) => {
                setTypeFilter(e.target.value);
                setPage(1);
              }}
              className="bg-slate-900 border border-slate-800 text-slate-200 text-xs rounded-lg px-2.5 py-1.5 focus:outline-none focus:ring-1 focus:ring-purple-500"
            >
              <option value="">All Event Types</option>
              <option value="TRACK_MODERATED">Track Moderated</option>
              <option value="TRACK_PUBLISHED">Track Published</option>
              <option value="UPLOAD_COMPLETE">Audio Processing Ready</option>
              <option value="TRACK_PROCESSING_FAILED">Processing Failed</option>
              <option value="CREATOR_APPLICATION">Creator Application</option>
              <option value="NEW_RELEASE">New Releases</option>
              <option value="SYSTEM">System Alerts</option>
            </select>
          </div>
        )}
      </div>

      {/* Main Tab Views */}
      {activeTab === "preferences" ? (
        /* Preferences Configuration Section */
        <div className="max-w-3xl space-y-6">
          <div className="rounded-xl border border-slate-800 bg-slate-900/50 p-6 backdrop-blur-sm">
            <h3 className="text-base font-semibold text-slate-100 flex items-center gap-2">
              <Sliders className="h-4 w-4 text-purple-400" />
              Delivery & Channel Preferences
            </h3>
            <p className="text-xs text-slate-400 mt-1">
              Configure how and when you receive automated notifications, alerts, and platform events.
            </p>

            {isPrefsLoading ? (
              <div className="mt-6 space-y-4 animate-pulse">
                {[1, 2, 3, 4].map((i) => (
                  <div key={i} className="h-14 rounded-lg bg-slate-800/50" />
                ))}
              </div>
            ) : preferencesData ? (
              <div className="mt-6 divide-y divide-slate-800/80">
                {/* Master Push Toggle */}
                <div className="py-4 flex items-center justify-between">
                  <div>
                    <h4 className="text-sm font-medium text-slate-200">Push Notifications</h4>
                    <p className="text-xs text-slate-400 mt-0.5">
                      Enable push dispatch to registered desktop and mobile devices.
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() =>
                      handleTogglePreference("push_enabled", preferencesData.push_enabled)
                    }
                    disabled={updatePrefsMutation.isPending}
                    className={cn(
                      "relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-purple-500",
                      preferencesData.push_enabled ? "bg-purple-600" : "bg-slate-700"
                    )}
                  >
                    <span
                      className={cn(
                        "pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out",
                        preferencesData.push_enabled ? "translate-x-5" : "translate-x-0"
                      )}
                    />
                  </button>
                </div>

                {/* Processing & Uploads */}
                <div className="py-4 flex items-center justify-between">
                  <div>
                    <h4 className="text-sm font-medium text-slate-200">Audio Processing & Transcoding</h4>
                    <p className="text-xs text-slate-400 mt-0.5">
                      Receive alerts when your uploads finish transcoding, waveform generation, or if errors occur.
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() =>
                      handleTogglePreference(
                        "processing_updates_enabled",
                        preferencesData.processing_updates_enabled
                      )
                    }
                    disabled={updatePrefsMutation.isPending}
                    className={cn(
                      "relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-purple-500",
                      preferencesData.processing_updates_enabled ? "bg-purple-600" : "bg-slate-700"
                    )}
                  >
                    <span
                      className={cn(
                        "pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out",
                        preferencesData.processing_updates_enabled ? "translate-x-5" : "translate-x-0"
                      )}
                    />
                  </button>
                </div>

                {/* New Releases */}
                <div className="py-4 flex items-center justify-between">
                  <div>
                    <h4 className="text-sm font-medium text-slate-200">New Releases & Publications</h4>
                    <p className="text-xs text-slate-400 mt-0.5">
                      Get notified when new songs and releases drop from followed artists.
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() =>
                      handleTogglePreference(
                        "new_releases_enabled",
                        preferencesData.new_releases_enabled
                      )
                    }
                    disabled={updatePrefsMutation.isPending}
                    className={cn(
                      "relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-purple-500",
                      preferencesData.new_releases_enabled ? "bg-purple-600" : "bg-slate-700"
                    )}
                  >
                    <span
                      className={cn(
                        "pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out",
                        preferencesData.new_releases_enabled ? "translate-x-5" : "translate-x-0"
                      )}
                    />
                  </button>
                </div>

                {/* Playlist Updates */}
                <div className="py-4 flex items-center justify-between">
                  <div>
                    <h4 className="text-sm font-medium text-slate-200">Playlist Updates</h4>
                    <p className="text-xs text-slate-400 mt-0.5">
                      Alerts when collaborative playlists you follow add new tracks.
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() =>
                      handleTogglePreference(
                        "playlist_updates_enabled",
                        preferencesData.playlist_updates_enabled
                      )
                    }
                    disabled={updatePrefsMutation.isPending}
                    className={cn(
                      "relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-purple-500",
                      preferencesData.playlist_updates_enabled ? "bg-purple-600" : "bg-slate-700"
                    )}
                  >
                    <span
                      className={cn(
                        "pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out",
                        preferencesData.playlist_updates_enabled ? "translate-x-5" : "translate-x-0"
                      )}
                    />
                  </button>
                </div>

                {/* Recommendations */}
                <div className="py-4 flex items-center justify-between">
                  <div>
                    <h4 className="text-sm font-medium text-slate-200">Personalized Recommendations</h4>
                    <p className="text-xs text-slate-400 mt-0.5">
                      Periodic updates when new algorithmic mixes and recommendations are generated.
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() =>
                      handleTogglePreference(
                        "recommendations_enabled",
                        preferencesData.recommendations_enabled
                      )
                    }
                    disabled={updatePrefsMutation.isPending}
                    className={cn(
                      "relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-purple-500",
                      preferencesData.recommendations_enabled ? "bg-purple-600" : "bg-slate-700"
                    )}
                  >
                    <span
                      className={cn(
                        "pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out",
                        preferencesData.recommendations_enabled ? "translate-x-5" : "translate-x-0"
                      )}
                    />
                  </button>
                </div>
              </div>
            ) : (
              <p className="text-sm text-rose-400 mt-4">Failed to load preferences.</p>
            )}
          </div>
        </div>
      ) : (
        /* Notifications List View */
        <div className="space-y-4">
          {isListLoading ? (
            <div className="space-y-3">
              {[1, 2, 3, 4, 5].map((i) => (
                <div
                  key={i}
                  className="rounded-xl border border-slate-800 bg-slate-900/40 p-4 animate-pulse flex items-start gap-4"
                >
                  <div className="h-10 w-10 rounded-lg bg-slate-800 shrink-0" />
                  <div className="flex-1 space-y-2">
                    <div className="h-4 w-1/3 rounded bg-slate-800" />
                    <div className="h-3 w-3/4 rounded bg-slate-800/60" />
                  </div>
                </div>
              ))}
            </div>
          ) : notifications.length === 0 ? (
            <div className="rounded-xl border border-slate-800 bg-slate-900/30 p-12 text-center">
              <Inbox className="h-12 w-12 text-slate-600 mx-auto mb-3 opacity-60" />
              <h3 className="text-base font-medium text-slate-200">No notifications found</h3>
              <p className="text-xs text-slate-500 max-w-sm mx-auto mt-1">
                {activeTab === "unread"
                  ? "You are all caught up! There are no unread notifications right now."
                  : "No events matching your current filters have occurred yet."}
              </p>
              {typeFilter && (
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setTypeFilter("")}
                  className="mt-4 border-slate-800 text-slate-300"
                >
                  Clear Filter
                </Button>
              )}
            </div>
          ) : (
            <div className="space-y-3">
              {notifications.map((item) => {
                const resourceLink = getTargetResourceLink(item);

                return (
                  <div
                    key={item.id}
                    className={cn(
                      "rounded-xl border p-4.5 transition-all flex flex-col sm:flex-row sm:items-start justify-between gap-4",
                      !item.is_read
                        ? "border-purple-500/30 bg-purple-950/15 shadow-sm shadow-purple-950/30"
                        : "border-slate-800/80 bg-slate-900/40 hover:bg-slate-900/70"
                    )}
                  >
                    <div className="flex items-start gap-3.5">
                      {/* Icon */}
                      <div className="h-10 w-10 rounded-xl bg-slate-800 border border-slate-700/60 flex items-center justify-center shrink-0 mt-0.5 shadow-inner">
                        {getNotificationIcon(item.type)}
                      </div>

                      {/* Content */}
                      <div className="space-y-1.5 min-w-0">
                        <div className="flex flex-wrap items-center gap-2">
                          <h4
                            className={cn(
                              "text-sm font-medium",
                              !item.is_read ? "text-white font-semibold" : "text-slate-200"
                            )}
                          >
                            {item.title}
                          </h4>
                          {getNotificationTypeBadge(item.type)}
                          {!item.is_read && (
                            <Badge variant="purple" className="text-[10px] py-0 px-1.5">
                              Unread
                            </Badge>
                          )}
                        </div>

                        <p className="text-xs text-slate-300 leading-relaxed max-w-2xl">
                          {item.body}
                        </p>

                        {/* Associated Resource Button */}
                        {resourceLink && (
                          <div className="pt-1">
                            <Link
                              href={resourceLink.href}
                              onClick={() => {
                                if (!item.is_read) {
                                  markReadMutation.mutate(item.id);
                                }
                              }}
                              className="inline-flex items-center gap-1.5 text-xs font-medium text-purple-400 hover:text-purple-300 transition-colors"
                            >
                              <span>{resourceLink.label}</span>
                              <ExternalLink className="h-3 w-3" />
                            </Link>
                          </div>
                        )}

                        <div className="flex items-center gap-2 text-[11px] text-slate-500 pt-1">
                          <Clock className="h-3 w-3" />
                          <span>{formatDateTime(item.created_at)}</span>
                        </div>
                      </div>
                    </div>

                    {/* Actions */}
                    <div className="flex items-center gap-2 shrink-0 self-end sm:self-center">
                      {!item.is_read && (
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => markReadMutation.mutate(item.id)}
                          disabled={markReadMutation.isPending}
                          className="text-xs text-slate-400 hover:text-purple-300"
                        >
                          <Check className="h-3.5 w-3.5 mr-1" />
                          <span>Mark Read</span>
                        </Button>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}

          {/* Pagination Controls */}
          {totalCount > pageSize && (
            <div className="flex items-center justify-between border-t border-slate-800 pt-4 px-2">
              <span className="text-xs text-slate-400">
                Showing <span className="font-medium text-slate-200">{skip + 1}</span> to{" "}
                <span className="font-medium text-slate-200">
                  {Math.min(skip + pageSize, totalCount)}
                </span>{" "}
                of <span className="font-medium text-slate-200">{totalCount}</span> entries
              </span>

              <div className="flex items-center gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setPage((p) => Math.max(1, p - 1))}
                  disabled={page <= 1}
                  className="border-slate-800 text-xs"
                >
                  <ChevronLeft className="h-3.5 w-3.5 mr-1" />
                  <span>Previous</span>
                </Button>
                <span className="text-xs text-slate-400">
                  Page {page} of {totalPages}
                </span>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                  disabled={page >= totalPages}
                  className="border-slate-800 text-xs"
                >
                  <span>Next</span>
                  <ChevronRight className="h-3.5 w-3.5 ml-1" />
                </Button>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
