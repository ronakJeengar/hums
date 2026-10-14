"use client";

import * as React from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  Activity,
  BarChart3,
  CheckCircle,
  FileText,
  Headphones,
  Home,
  ListMusic,
  Music2,
  Radio,
  ShieldAlert,
  Sparkles,
  Users,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { UserRole } from "@/types";

interface NavItem {
  title: string;
  href: string;
  icon: React.ReactNode;
}

interface SidebarProps {
  role?: UserRole | null;
  experience: "admin" | "studio";
}

export function Sidebar({ role, experience }: SidebarProps) {
  const pathname = usePathname();

  const adminNavItems: NavItem[] = [
    {
      title: "Overview",
      href: "/admin/dashboard",
      icon: <Home className="h-4 w-4" />,
    },
    {
      title: "Users",
      href: "/admin/users",
      icon: <Users className="h-4 w-4" />,
    },
    {
      title: "Creators",
      href: "/admin/creators",
      icon: <Radio className="h-4 w-4" />,
    },
    {
      title: "Applications",
      href: "/admin/applications",
      icon: <CheckCircle className="h-4 w-4" />,
    },
    {
      title: "Tracks & Content",
      href: "/admin/tracks",
      icon: <Music2 className="h-4 w-4" />,
    },
    {
      title: "Reports Queue",
      href: "/admin/reports",
      icon: <ShieldAlert className="h-4 w-4" />,
    },
    {
      title: "Operations & Health",
      href: "/admin/operations",
      icon: <Activity className="h-4 w-4" />,
    },
    {
      title: "Audit Logs",
      href: "/admin/audit-logs",
      icon: <FileText className="h-4 w-4" />,
    },
  ];

  const studioNavItems: NavItem[] = [
    {
      title: "Studio Dashboard",
      href: "/studio/dashboard",
      icon: <Home className="h-4 w-4" />,
    },
    {
      title: "My Tracks",
      href: "/studio/tracks",
      icon: <ListMusic className="h-4 w-4" />,
    },
    {
      title: "Upload New Track",
      href: "/studio/upload",
      icon: <Sparkles className="h-4 w-4" />,
    },
    {
      title: "Analytics",
      href: "/studio/analytics",
      icon: <BarChart3 className="h-4 w-4" />,
    },
    {
      title: "Artist Profile",
      href: "/studio/profile",
      icon: <Headphones className="h-4 w-4" />,
    },
  ];

  const items = experience === "admin" ? adminNavItems : studioNavItems;

  return (
    <aside className="w-64 shrink-0 border-r border-slate-800 bg-slate-950/95 min-h-screen flex flex-col justify-between p-4">
      <div>
        {/* Brand Header */}
        <div className="flex items-center gap-3 px-2 py-3 mb-6">
          <div className="h-8 w-8 rounded-lg bg-gradient-to-tr from-purple-600 to-indigo-500 flex items-center justify-center shadow-lg shadow-purple-900/40">
            <Music2 className="h-5 w-5 text-white" />
          </div>
          <div>
            <h1 className="text-base font-bold tracking-tight text-white">
              Hums
            </h1>
            <span className="text-[10px] font-semibold uppercase tracking-wider text-purple-400">
              {experience === "admin" ? "Admin Panel" : "Creator Studio"}
            </span>
          </div>
        </div>

        {/* Experience Switcher if Admin */}
        {role === "admin" && (
          <div className="mb-6 p-2 rounded-lg bg-slate-900 border border-slate-800">
            <span className="text-[10px] uppercase font-semibold text-slate-500 px-2 block mb-1">
              Switch Workspace
            </span>
            <div className="grid grid-cols-2 gap-1 text-xs">
              <Link
                href="/admin/dashboard"
                className={cn(
                  "px-2 py-1.5 rounded text-center font-medium transition-colors",
                  experience === "admin"
                    ? "bg-purple-600 text-white"
                    : "text-slate-400 hover:text-slate-200"
                )}
              >
                Admin
              </Link>
              <Link
                href="/studio/dashboard"
                className={cn(
                  "px-2 py-1.5 rounded text-center font-medium transition-colors",
                  experience === "studio"
                    ? "bg-purple-600 text-white"
                    : "text-slate-400 hover:text-slate-200"
                )}
              >
                Studio
              </Link>
            </div>
          </div>
        )}

        {/* Navigation Links */}
        <nav className="space-y-1">
          {items.map((item) => {
            const isActive = pathname === item.href || (item.href !== "/admin/dashboard" && item.href !== "/studio/dashboard" && pathname.startsWith(item.href));
            return (
              <Link
                key={item.href}
                href={item.href}
                className={cn(
                  "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors",
                  isActive
                    ? "bg-purple-600/15 text-purple-300 border border-purple-500/30"
                    : "text-slate-400 hover:text-slate-200 hover:bg-slate-900/60"
                )}
              >
                {item.icon}
                {item.title}
              </Link>
            );
          })}
        </nav>
      </div>

      {/* Footer Info */}
      <div className="border-t border-slate-800/80 pt-4 px-2">
        <div className="flex items-center justify-between text-xs text-slate-500">
          <span>Hums Web v1.0</span>
          <span className="inline-block h-2 w-2 rounded-full bg-emerald-500" />
        </div>
      </div>
    </aside>
  );
}
