import { NextRequest, NextResponse } from "next/server";
import {
  ACCESS_TOKEN_COOKIE,
  REFRESH_TOKEN_COOKIE,
  USER_ROLE_COOKIE,
} from "./lib/auth/session";
import { canAccessAdmin, canAccessStudio, getDefaultDashboardRoute } from "./lib/permissions/roles";
import { UserRole } from "./types";

export function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;

  const accessToken = req.cookies.get(ACCESS_TOKEN_COOKIE)?.value;
  const refreshToken = req.cookies.get(REFRESH_TOKEN_COOKIE)?.value;
  const userRole = (req.cookies.get(USER_ROLE_COOKIE)?.value as UserRole) || null;

  const isAuthenticated = Boolean(accessToken || refreshToken);

  // 1. Auth Page (/login)
  if (pathname === "/login") {
    if (isAuthenticated && userRole) {
      const destination = getDefaultDashboardRoute(userRole);
      return NextResponse.redirect(new URL(destination, req.url));
    }
    return NextResponse.next();
  }

  // 2. Protected Admin Routes (/admin/*)
  if (pathname.startsWith("/admin")) {
    if (!isAuthenticated) {
      const loginUrl = new URL("/login", req.url);
      loginUrl.searchParams.set("from", pathname);
      return NextResponse.redirect(loginUrl);
    }

    if (userRole && !canAccessAdmin(userRole)) {
      // Unauthorized for admin
      const fallback = canAccessStudio(userRole)
        ? "/studio/dashboard"
        : "/apply-creator";
      return NextResponse.redirect(new URL(fallback, req.url));
    }

    return NextResponse.next();
  }

  // 3. Protected Creator Studio Routes (/studio/*)
  if (pathname.startsWith("/studio")) {
    if (!isAuthenticated) {
      const loginUrl = new URL("/login", req.url);
      loginUrl.searchParams.set("from", pathname);
      return NextResponse.redirect(loginUrl);
    }

    if (userRole && !canAccessStudio(userRole)) {
      // Unauthorized for studio
      const fallback = canAccessAdmin(userRole)
        ? "/admin/dashboard"
        : "/apply-creator";
      return NextResponse.redirect(new URL(fallback, req.url));
    }

    return NextResponse.next();
  }

  // 4. Root redirect
  if (pathname === "/") {
    if (isAuthenticated && userRole) {
      return NextResponse.redirect(new URL(getDefaultDashboardRoute(userRole), req.url));
    }
    return NextResponse.redirect(new URL("/login", req.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    "/",
    "/login",
    "/admin/:path*",
    "/studio/:path*",
    "/apply-creator/:path*",
  ],
};
