"use client";

import * as React from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import { Headphones, Lock, Mail, Music2, ShieldCheck } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { api, ApiError } from "@/lib/api/client";
import { getDefaultDashboardRoute } from "@/lib/permissions/roles";

const loginSchema = z.object({
  email: z.string().email("Please enter a valid email address"),
  password: z.string().min(1, "Password is required"),
});

type LoginFormValues = z.infer<typeof loginSchema>;

function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const redirectFrom = searchParams.get("from");

  const [serverError, setServerError] = React.useState<string | null>(null);
  const [isLoading, setIsLoading] = React.useState(false);

  const {
    register,
    handleSubmit,
    setValue,
    formState: { errors },
  } = useForm<LoginFormValues>({
    resolver: zodResolver(loginSchema),
    defaultValues: {
      email: "",
      password: "",
    },
  });

  const onSubmit = async (values: LoginFormValues) => {
    setIsLoading(true);
    setServerError(null);

    try {
      const { user } = await api.auth.login(values.email, values.password);
      const destination = redirectFrom || getDefaultDashboardRoute(user.role);
      router.push(destination);
      router.refresh();
    } catch (err: unknown) {
      if (err instanceof ApiError) {
        setServerError(err.message);
      } else {
        setServerError("Failed to sign in. Please verify your credentials.");
      }
    } finally {
      setIsLoading(false);
    }
  };

  const fillQuickAccount = (email: string, pass: string) => {
    setValue("email", email);
    setValue("password", pass);
  };

  return (
    <div className="w-full max-w-md relative z-10">
      <div className="text-center mb-8">
        <div className="inline-flex h-12 w-12 rounded-xl bg-gradient-to-tr from-purple-600 to-indigo-500 items-center justify-center shadow-lg shadow-purple-900/50 mb-4">
          <Music2 className="h-6 w-6 text-white" />
        </div>
        <h1 className="text-2xl font-bold tracking-tight text-white">
          Hums Web Platform
        </h1>
        <p className="text-sm text-slate-400 mt-1">
          Sign in to access the Admin Panel or Creator Studio
        </p>
      </div>

      {/* Card */}
      <div className="rounded-2xl border border-slate-800 bg-slate-900/80 p-8 backdrop-blur-xl shadow-2xl">
        {serverError && (
          <div className="mb-6 rounded-lg border border-rose-800/60 bg-rose-950/50 p-3 text-xs text-rose-300">
            {serverError}
          </div>
        )}

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              Email Address
            </label>
            <Input
              type="email"
              placeholder="name@hums.app"
              icon={<Mail className="h-4 w-4" />}
              error={errors.email?.message}
              {...register("email")}
            />
          </div>

          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              Password
            </label>
            <Input
              type="password"
              placeholder="••••••••••••"
              icon={<Lock className="h-4 w-4" />}
              error={errors.password?.message}
              {...register("password")}
            />
          </div>

          <Button
            type="submit"
            className="w-full mt-2"
            isLoading={isLoading}
            size="lg"
          >
            Sign In
          </Button>
        </form>

        {/* Quick Login Helpers for Testing */}
        <div className="mt-8 pt-6 border-t border-slate-800/80">
          <span className="text-[11px] font-semibold uppercase tracking-wider text-slate-500 block text-center mb-3">
            One-Click Seed Credentials
          </span>
          <div className="grid grid-cols-2 gap-2 text-xs">
            <button
              type="button"
              onClick={() =>
                fillQuickAccount("admin@hums.app", "AdminPassword123!")
              }
              className="flex items-center justify-center gap-1.5 p-2 rounded-lg border border-slate-800 bg-slate-950 hover:bg-slate-800/60 text-slate-300 hover:text-white transition-colors cursor-pointer"
            >
              <ShieldCheck className="h-3.5 w-3.5 text-purple-400" />
              <span>Admin User</span>
            </button>
            <button
              type="button"
              onClick={() =>
                fillQuickAccount("creator@hums.app", "CreatorPassword123!")
              }
              className="flex items-center justify-center gap-1.5 p-2 rounded-lg border border-slate-800 bg-slate-950 hover:bg-slate-800/60 text-slate-300 hover:text-white transition-colors cursor-pointer"
            >
              <Headphones className="h-3.5 w-3.5 text-indigo-400" />
              <span>Creator User</span>
            </button>
          </div>
        </div>
      </div>

      <p className="text-center text-xs text-slate-500 mt-6">
        Hums Audio Platform &copy; 2026. All rights reserved.
      </p>
    </div>
  );
}

export default function LoginPage() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-[#07090e] p-4 relative overflow-hidden">
      <div className="absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2 w-96 h-96 bg-purple-600/10 rounded-full blur-3xl pointer-events-none" />
      <React.Suspense fallback={<div className="text-slate-500 text-xs">Loading portal...</div>}>
        <LoginForm />
      </React.Suspense>
    </div>
  );
}
