"use client";

import * as React from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  Bell,
  CheckCheck,
  Sparkles,
  CheckCircle,
  AlertCircle,
  Radio,
  FileText,
  Clock,
  ExternalLink,
} from "lucide-react";
import { api } from "@/lib/api/client";
import { NotificationItem, User } from "@/types";
import { cn } from "@/lib/utils";

interface NotificationBellProps {
  user?: User | null;
}

function getNotificationIcon(type: string) {
  switch (type) {
    case "UPLOAD_COMPLETE":
    case "TRACK_PUBLISHED":
      return <Sparkles className="h-4 w-4 text-emerald-400" />;
    case "TRACK_PROCESSING_FAILED":
      return <AlertCircle className="h-4 w-4 text-rose-400" />;
    case "TRACK_MODERATED":
      return <FileText className="h-4 w-4 text-purple-400" />;
    case "CREATOR_APPLICATION":
      return <CheckCircle className="h-4 w-4 text-indigo-400" />;
    case "NEW_RELEASE":
    case "PLAYLIST_UPDATE":
      return <Radio className="h-4 w-4 text-cyan-400" />;
    default:
      return <Bell className="h-4 w-4 text-slate-400" />;
  }
}

function formatRelativeTime(dateString: string): string {
  try {
    const date = new Date(dateString);
    const now = new Date();
    const diffInSeconds = Math.floor((now.getTime() - date.getTime()) / 1000);

    if (diffInSeconds < 60) return "just now";
    const diffInMinutes = Math.floor(diffInSeconds / 60);
    if (diffInMinutes < 60) return `${diffInMinutes}m ago`;
    const diffInHours = Math.floor(diffInMinutes / 60);
    if (diffInHours < 24) return `${diffInHours}h ago`;
    const diffInDays = Math.floor(diffInHours / 24);
    if (diffInDays < 7) return `${diffInDays}d ago`;
    return date.toLocaleDateString(undefined, { month: "short", day: "numeric" });
  } catch {
    return "";
  }
}

export function NotificationBell({ user }: NotificationBellProps) {
  const router = useRouter();
  const queryClient = useQueryClient();
  const [isOpen, setIsOpen] = React.useState(false);
  const containerRef = React.useRef<HTMLDivElement>(null);

  // Poll unread count every 20 seconds
  const { data: unreadData } = useQuery({
    queryKey: ["notifications", "unread-count"],
    queryFn: () => api.notifications.getUnreadCount(),
    refetchInterval: 20000,
  });

  // Fetch recent notifications when dropdown is open
  const { data: notificationsData, isLoading } = useQuery({
    queryKey: ["notifications", "recent"],
    queryFn: () => api.notifications.list({ limit: 6 }),
    enabled: isOpen,
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

  // Close on outside click or Escape
  React.useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    }
    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        setIsOpen(false);
      }
    }

    if (isOpen) {
      document.addEventListener("mousedown", handleClickOutside);
      document.addEventListener("keydown", handleKeyDown);
    }
    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [isOpen]);

  const unreadCount = unreadData?.unread_count ?? 0;
  const recentNotifications = notificationsData?.items ?? [];

  const activityCenterUrl =
    user?.role === "admin"
      ? "/admin/notifications"
      : user?.role === "creator"
      ? "/studio/notifications"
      : "/studio/notifications";

  const handleNotificationClick = (item: NotificationItem) => {
    if (!item.is_read) {
      markReadMutation.mutate(item.id);
    }

    // Direct user to target if relevant data exists
    if (item.data && typeof item.data === "object") {
      const dataObj = item.data as Record<string, unknown>;
      if (dataObj.track_id) {
        setIsOpen(false);
        if (user?.role === "admin") {
          router.push(`/admin/tracks/${dataObj.track_id}`);
        } else {
          router.push(`/studio/tracks/${dataObj.track_id}`);
        }
        return;
      }
      if (dataObj.application_id && user?.role === "admin") {
        setIsOpen(false);
        router.push("/admin/applications");
        return;
      }
    }

    setIsOpen(false);
    router.push(activityCenterUrl);
  };

  return (
    <div className="relative inline-block" ref={containerRef}>
      <button
        type="button"
        onClick={() => setIsOpen((prev) => !prev)}
        aria-label="View notifications"
        aria-expanded={isOpen}
        className={cn(
          "relative p-2 rounded-lg text-slate-300 hover:text-white hover:bg-slate-800 transition-colors focus:outline-none focus:ring-2 focus:ring-purple-500/50",
          isOpen && "bg-slate-800 text-white"
        )}
      >
        <Bell className="h-4 w-4" />
        {unreadCount > 0 && (
          <span className="absolute top-1 right-1 flex h-4 min-w-4 px-1 items-center justify-center rounded-full bg-rose-500 text-[10px] font-bold text-white shadow-sm shadow-rose-900/50 ring-2 ring-slate-950 animate-in zoom-in-50">
            {unreadCount > 99 ? "99+" : unreadCount}
          </span>
        )}
      </button>

      {isOpen && (
        <div
          role="dialog"
          aria-label="Notifications popover"
          className="absolute right-0 mt-2 w-80 sm:w-96 rounded-xl border border-slate-800 bg-slate-900/95 backdrop-blur-xl shadow-2xl shadow-black/80 z-50 overflow-hidden animate-in fade-in-50 zoom-in-95 duration-150"
        >
          {/* Header */}
          <div className="flex items-center justify-between border-b border-slate-800 px-4 py-3 bg-slate-950/40">
            <div className="flex items-center gap-2">
              <span className="text-sm font-semibold text-slate-100">Notifications</span>
              {unreadCount > 0 && (
                <span className="rounded-full bg-purple-500/20 px-2 py-0.5 text-[11px] font-medium text-purple-300 border border-purple-500/30">
                  {unreadCount} new
                </span>
              )}
            </div>

            {unreadCount > 0 && (
              <button
                type="button"
                onClick={() => markAllMutation.mutate()}
                disabled={markAllMutation.isPending}
                className="flex items-center gap-1 text-xs text-purple-400 hover:text-purple-300 transition-colors disabled:opacity-50"
              >
                <CheckCheck className="h-3.5 w-3.5" />
                <span>Mark all read</span>
              </button>
            )}
          </div>

          {/* List Content */}
          <div className="max-h-[380px] overflow-y-auto divide-y divide-slate-800/60">
            {isLoading ? (
              <div className="p-4 space-y-3">
                {[1, 2, 3].map((i) => (
                  <div key={i} className="flex gap-3 animate-pulse">
                    <div className="h-8 w-8 rounded-lg bg-slate-800 shrink-0" />
                    <div className="flex-1 space-y-2">
                      <div className="h-3 w-3/4 rounded bg-slate-800" />
                      <div className="h-2 w-1/2 rounded bg-slate-800/60" />
                    </div>
                  </div>
                ))}
              </div>
            ) : recentNotifications.length === 0 ? (
              <div className="py-10 px-4 text-center">
                <Bell className="h-8 w-8 text-slate-600 mx-auto mb-2 opacity-50" />
                <p className="text-xs font-medium text-slate-300">No notifications yet</p>
                <p className="text-[11px] text-slate-500 mt-0.5">
                  We will notify you about your uploads, moderation, and activity here.
                </p>
              </div>
            ) : (
              recentNotifications.map((notif) => (
                <div
                  key={notif.id}
                  onClick={() => handleNotificationClick(notif)}
                  className={cn(
                    "flex items-start gap-3 p-3.5 transition-colors cursor-pointer group hover:bg-slate-800/50 relative",
                    !notif.is_read ? "bg-purple-950/20" : "bg-transparent"
                  )}
                >
                  {/* Icon */}
                  <div className="h-8 w-8 rounded-lg bg-slate-800 border border-slate-700/60 flex items-center justify-center shrink-0 mt-0.5">
                    {getNotificationIcon(notif.type)}
                  </div>

                  {/* Body */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-baseline justify-between gap-2">
                      <h4
                        className={cn(
                          "text-xs truncate",
                          !notif.is_read
                            ? "font-semibold text-slate-100"
                            : "font-medium text-slate-300"
                        )}
                      >
                        {notif.title}
                      </h4>
                      <span className="text-[10px] text-slate-500 shrink-0 flex items-center gap-1">
                        <Clock className="h-2.5 w-2.5" />
                        {formatRelativeTime(notif.created_at)}
                      </span>
                    </div>
                    <p className="text-[11px] text-slate-400 line-clamp-2 mt-0.5 leading-relaxed">
                      {notif.body}
                    </p>
                  </div>

                  {/* Unread indicator */}
                  {!notif.is_read && (
                    <span className="h-2 w-2 rounded-full bg-purple-500 ring-2 ring-purple-900/50 shrink-0 mt-2" />
                  )}
                </div>
              ))
            )}
          </div>

          {/* Footer */}
          <div className="border-t border-slate-800 bg-slate-950/60 px-4 py-2.5 flex items-center justify-between text-xs">
            <Link
              href={activityCenterUrl}
              onClick={() => setIsOpen(false)}
              className="font-medium text-purple-400 hover:text-purple-300 flex items-center gap-1.5 transition-colors"
            >
              <span>Open Activity Center</span>
              <ExternalLink className="h-3 w-3" />
            </Link>
            <span className="text-[10px] text-slate-500">Hums Live Updates</span>
          </div>
        </div>
      )}
    </div>
  );
}
