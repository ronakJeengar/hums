"use client";

import * as React from "react";
import { useQuery } from "@tanstack/react-query";
import { Sidebar } from "@/components/shared/sidebar";
import { Navbar } from "@/components/shared/navbar";
import { api } from "@/lib/api/client";

export default function StudioLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const { data: user } = useQuery({
    queryKey: ["current-user"],
    queryFn: () => api.auth.getMe(),
  });

  return (
    <div className="flex min-h-screen bg-[#090a0f]">
      <Sidebar role={user?.role} experience="studio" />
      <div className="flex-1 flex flex-col min-w-0">
        <Navbar user={user} title="Creator Studio" />
        <main className="flex-1 p-6 overflow-y-auto">{children}</main>
      </div>
    </div>
  );
}
