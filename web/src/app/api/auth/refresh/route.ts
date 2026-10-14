import { NextRequest, NextResponse } from "next/server";
import {
  ACCESS_TOKEN_COOKIE,
  BACKEND_API_URL,
  REFRESH_TOKEN_COOKIE,
  USER_ROLE_COOKIE,
} from "@/lib/auth/session";

export async function POST(req: NextRequest) {
  try {
    const refreshToken = req.cookies.get(REFRESH_TOKEN_COOKIE)?.value;

    if (!refreshToken) {
      return NextResponse.json(
        { success: false, error: { message: "No refresh token available" } },
        { status: 401 }
      );
    }

    const backendRes = await fetch(`${BACKEND_API_URL}/api/v1/auth/refresh`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ refresh_token: refreshToken }),
    });

    const data = await backendRes.json();

    if (!backendRes.ok || !data.success) {
      const resp = NextResponse.json(
        { success: false, error: data.error || { message: "Session expired" } },
        { status: 401 }
      );
      resp.cookies.delete(ACCESS_TOKEN_COOKIE);
      resp.cookies.delete(REFRESH_TOKEN_COOKIE);
      resp.cookies.delete(USER_ROLE_COOKIE);
      return resp;
    }

    const { access_token, refresh_token: new_refresh_token } = data.data;
    const isProduction = process.env.NODE_ENV === "production";

    const response = NextResponse.json({ success: true });

    response.cookies.set(ACCESS_TOKEN_COOKIE, access_token, {
      httpOnly: true,
      secure: isProduction,
      sameSite: "lax",
      path: "/",
      maxAge: 60 * 60,
    });

    if (new_refresh_token) {
      response.cookies.set(REFRESH_TOKEN_COOKIE, new_refresh_token, {
        httpOnly: true,
        secure: isProduction,
        sameSite: "lax",
        path: "/",
        maxAge: 30 * 24 * 60 * 60,
      });
    }

    return response;
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "Refresh failed";
    return NextResponse.json(
      { success: false, error: { message: msg } },
      { status: 500 }
    );
  }
}
