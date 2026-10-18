import * as React from "react";
import { cn } from "@/lib/utils";

export interface InputProps
  extends React.InputHTMLAttributes<HTMLInputElement> {
  error?: string;
  icon?: React.ReactNode;
}

export const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ className, type, error, icon, ...props }, ref) => {
    return (
      <div className="w-full">
        <div className="relative flex items-center">
          {icon && (
            <div className="absolute left-3 text-slate-400 pointer-events-none">
              {icon}
            </div>
          )}
          <input
            type={type}
            className={cn(
              "flex h-9.5 w-full rounded-lg border border-slate-700/80 bg-slate-900/90 px-3 py-1.5 text-sm text-slate-100 placeholder:text-slate-500 shadow-sm transition-colors",
              "focus:outline-none focus:border-purple-500 focus:ring-1 focus:ring-purple-500",
              "disabled:cursor-not-allowed disabled:opacity-50",
              icon && "pl-9",
              error && "border-rose-500 focus:border-rose-500 focus:ring-rose-500",
              className
            )}
            ref={ref}
            {...props}
          />
        </div>
        {error && <p className="mt-1 text-xs text-rose-400">{error}</p>}
      </div>
    );
  }
);
Input.displayName = "Input";
