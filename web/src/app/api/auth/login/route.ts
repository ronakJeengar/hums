import { NextRequest, NextResponse } from "next/server";
import {
  ACCESS_TOKEN_COOKIE,
  BACKEND_API_URL,
  REFRESH_TOKEN_COOKIE,
  USER_ROLE_COOKIE,
} from "@/lib/auth/session";

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { email, password } = body;

    if (!email || !password) {
      return NextResponse.json(
        { success: false, error: { message: "Email and password are required" } },
        { status: 400 }
      );
    }

    const backendRes = await fetch(`${BACKEND_API_URL}/api/v1/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
    });

    const data = await backendRes.json();

    if (!backendRes.ok || !data.success) {
      return NextResponse.json(
        {
          success: false,
          error: data.error || { message: "Invalid email or password" },
        },
        { status: backendRes.status || 401 }
      );
    }

    const { access_token, refresh_token, user } = data.data;
    const isProduction = process.env.NODE_ENV === "production";

    const response = NextResponse.json({
      success: true,
      data: { user },
    });

    // Set HttpOnly access token cookie (valid 60 minutes)
    response.cookies.set(ACCESS_TOKEN_COOKIE, access_token, {
      httpOnly: true,
      secure: isProduction,
      sameSite: "lax",
      path: "/",
      maxAge: 60 * 60, // 1 hour
    });

    // Set HttpOnly refresh token cookie (valid 30 days)
    response.cookies.set(REFRESH_TOKEN_COOKIE, refresh_token, {
      httpOnly: true,
      secure: isProduction,
      sameSite: "lax",
      path: "/",
      maxAge: 30 * 24 * 60 * 60, // 30 days
    });

    // Set non-sensitive role cookie for edge middleware navigation
    response.cookies.set(USER_ROLE_COOKIE, user.role || "listener", {
      httpOnly: false,
      secure: isProduction,
      sameSite: "lax",
      path: "/",
      maxAge: 30 * 24 * 60 * 60,
    });

    return response;
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "Failed to process login request";
    return NextResponse.json(
      {
        success: false,
        error: { message: msg },
      },
      { status: 500 }
    );
  }
}
