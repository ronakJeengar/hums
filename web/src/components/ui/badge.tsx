import * as React from "react";
import { cn } from "@/lib/utils";

export interface BadgeProps extends React.HTMLAttributes<HTMLDivElement> {
  variant?:
    | "default"
    | "success"
    | "warning"
    | "danger"
    | "info"
    | "purple"
    | "outline";
}

export function Badge({
  className,
  variant = "default",
  ...props
}: BadgeProps) {
  const variantStyles = {
    default: "bg-slate-800 text-slate-300 border-slate-700",
    success: "bg-emerald-950/70 text-emerald-300 border-emerald-800/60",
    warning: "bg-amber-950/70 text-amber-300 border-amber-800/60",
    danger: "bg-rose-950/70 text-rose-300 border-rose-800/60",
    info: "bg-sky-950/70 text-sky-300 border-sky-800/60",
    purple: "bg-purple-950/70 text-purple-300 border-purple-800/60",
    outline: "bg-transparent text-slate-400 border-slate-700",
  };

  return (
    <div
      className={cn(
        "inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-semibold tracking-wide transition-colors",
        variantStyles[variant],
        className
      )}
      {...props}
    />
  );
}

export function StatusBadge({ status }: { status: string }) {
  const norm = status?.toUpperCase() || "";
  let variant: BadgeProps["variant"] = "default";

  if (["READY", "APPROVED", "RESOLVED", "ACTIVE", "COMPLETED"].includes(norm)) {
    variant = "success";
  } else if (["PENDING", "INVESTIGATING", "PROCESSING"].includes(norm)) {
    variant = "warning";
  } else if (["FAILED", "REJECTED", "MODERATED", "SUSPENDED"].includes(norm)) {
    variant = "danger";
  } else if (["UPLOADED", "DISMISSED"].includes(norm)) {
    variant = "info";
  }

  return <Badge variant={variant}>{status}</Badge>;
}
