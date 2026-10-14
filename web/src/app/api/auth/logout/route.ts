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
    const accessToken = req.cookies.get(ACCESS_TOKEN_COOKIE)?.value;

    if (refreshToken && accessToken) {
      try {
        await fetch(`${BACKEND_API_URL}/api/v1/auth/logout`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({ refresh_token: refreshToken }),
        });
      } catch {
        // Continue clearing cookies regardless
      }
    }

    const response = NextResponse.json({ success: true, message: "Logged out" });

    response.cookies.delete(ACCESS_TOKEN_COOKIE);
    response.cookies.delete(REFRESH_TOKEN_COOKIE);
    response.cookies.delete(USER_ROLE_COOKIE);

    return response;
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "Failed to logout";
    return NextResponse.json(
      { success: false, error: { message: msg } },
      { status: 500 }
    );
  }
}
