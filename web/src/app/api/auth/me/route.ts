import { NextRequest, NextResponse } from "next/server";
import {
  ACCESS_TOKEN_COOKIE,
  BACKEND_API_URL,
  REFRESH_TOKEN_COOKIE,
  USER_ROLE_COOKIE,
} from "@/lib/auth/session";

export async function GET(req: NextRequest) {
  try {
    let accessToken = req.cookies.get(ACCESS_TOKEN_COOKIE)?.value;
    const refreshToken = req.cookies.get(REFRESH_TOKEN_COOKIE)?.value;

    if (!accessToken && !refreshToken) {
      return NextResponse.json(
        { success: false, error: { message: "Unauthenticated" } },
        { status: 401 }
      );
    }

    let backendRes = accessToken
      ? await fetch(`${BACKEND_API_URL}/api/v1/users/me`, {
          headers: { Authorization: `Bearer ${accessToken}` },
        })
      : null;

    // Auto-refresh if token expired
    if ((!backendRes || backendRes.status === 401) && refreshToken) {
      const refreshRes = await fetch(`${BACKEND_API_URL}/api/v1/auth/refresh`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refresh_token: refreshToken }),
      });

      if (refreshRes.ok) {
        const refreshData = await refreshRes.json();
        if (refreshData.success) {
          accessToken = refreshData.data.access_token;
          backendRes = await fetch(`${BACKEND_API_URL}/api/v1/users/me`, {
            headers: { Authorization: `Bearer ${accessToken}` },
          });
        }
      }
    }

    if (!backendRes || !backendRes.ok) {
      const resp = NextResponse.json(
        { success: false, error: { message: "Session expired" } },
        { status: 401 }
      );
      resp.cookies.delete(ACCESS_TOKEN_COOKIE);
      resp.cookies.delete(REFRESH_TOKEN_COOKIE);
      resp.cookies.delete(USER_ROLE_COOKIE);
      return resp;
    }

    const data = await backendRes.json();
    const user = data.data;

    const response = NextResponse.json({
      success: true,
      data: { user },
    });

    if (accessToken) {
      response.cookies.set(ACCESS_TOKEN_COOKIE, accessToken, {
        httpOnly: true,
        secure: process.env.NODE_ENV === "production",
        sameSite: "lax",
        path: "/",
        maxAge: 60 * 60,
      });
    }

    response.cookies.set(USER_ROLE_COOKIE, user.role || "listener", {
      httpOnly: false,
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax",
      path: "/",
      maxAge: 30 * 24 * 60 * 60,
    });

    return response;
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "Failed to fetch user session";
    return NextResponse.json(
      { success: false, error: { message: msg } },
      { status: 500 }
    );
  }
}
