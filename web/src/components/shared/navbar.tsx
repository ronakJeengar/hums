"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { LogOut, User as UserIcon } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { NotificationBell } from "@/components/shared/notification-bell";
import { api } from "@/lib/api/client";
import { User } from "@/types";

interface NavbarProps {
  user?: User | null;
  title?: string;
}

export function Navbar({ user, title }: NavbarProps) {
  const router = useRouter();
  const [isLoggingOut, setIsLoggingOut] = React.useState(false);

  const handleLogout = async () => {
    setIsLoggingOut(true);
    try {
      await api.auth.logout();
      router.push("/login");
      router.refresh();
    } catch {
      router.push("/login");
    } finally {
      setIsLoggingOut(false);
    }
  };

  return (
    <header className="h-16 border-b border-slate-800 bg-slate-950/60 backdrop-blur-md px-6 flex items-center justify-between sticky top-0 z-30">
      <div className="flex items-center gap-4">
        {title && (
          <h2 className="text-base font-semibold text-slate-100">{title}</h2>
        )}
      </div>

      <div className="flex items-center gap-4">
        {user && <NotificationBell user={user} />}

        {user && (
          <div className="flex items-center gap-3">
            <div className="text-right">
              <div className="text-xs font-medium text-slate-200">
                {user.full_name || user.email}
              </div>
              <div className="text-[10px] text-slate-400 capitalize flex items-center justify-end gap-1.5 mt-0.5">
                <Badge variant="purple" className="text-[9px] px-1.5 py-0">
                  {user.role}
                </Badge>
              </div>
            </div>
            <div className="h-8 w-8 rounded-full bg-slate-800 border border-slate-700 flex items-center justify-center text-slate-300">
              <UserIcon className="h-4 w-4" />
            </div>
          </div>
        )}

        <Button
          variant="ghost"
          size="sm"
          isLoading={isLoggingOut}
          onClick={handleLogout}
          className="text-slate-400 hover:text-rose-400"
          title="Sign out"
        >
          <LogOut className="h-4 w-4" />
          <span className="hidden sm:inline">Logout</span>
        </Button>
      </div>
    </header>
  );
}
