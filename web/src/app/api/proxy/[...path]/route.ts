import { NextRequest, NextResponse } from "next/server";
import {
  ACCESS_TOKEN_COOKIE,
  BACKEND_API_URL,
  REFRESH_TOKEN_COOKIE,
  USER_ROLE_COOKIE,
} from "@/lib/auth/session";

async function handleProxy(req: NextRequest, { params }: { params: Promise<{ path: string[] }> }) {
  const resolvedParams = await params;
  const path = resolvedParams.path ? resolvedParams.path.join("/") : "";
  const searchParams = req.nextUrl.searchParams.toString();
  const queryString = searchParams ? `?${searchParams}` : "";
  const targetUrl = `${BACKEND_API_URL}/api/v1/${path}${queryString}`;

  let accessToken = req.cookies.get(ACCESS_TOKEN_COOKIE)?.value;
  const refreshToken = req.cookies.get(REFRESH_TOKEN_COOKIE)?.value;

  const headers: Record<string, string> = {};
  if (accessToken) {
    headers["Authorization"] = `Bearer ${accessToken}`;
  }
  const contentType = req.headers.get("content-type");
  if (contentType && !contentType.includes("multipart/form-data")) {
    headers["Content-Type"] = contentType;
  }

  let body: BodyInit | undefined = undefined;
  if (req.method !== "GET" && req.method !== "HEAD") {
    if (contentType?.includes("multipart/form-data")) {
      body = await req.formData();
    } else {
      body = await req.text();
    }
  }

  let backendRes = await fetch(targetUrl, {
    method: req.method,
    headers,
    body: body ? body : undefined,
  });

  // If 401 Unauthorized and refresh token exists, attempt refresh and retry once
  if (backendRes.status === 401 && refreshToken) {
    try {
      const refreshRes = await fetch(`${BACKEND_API_URL}/api/v1/auth/refresh`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refresh_token: refreshToken }),
      });

      if (refreshRes.ok) {
        const refreshData = await refreshRes.json();
        if (refreshData.success) {
          accessToken = refreshData.data.access_token;
          headers["Authorization"] = `Bearer ${accessToken}`;

          backendRes = await fetch(targetUrl, {
            method: req.method,
            headers,
            body: body ? body : undefined,
          });

          // Return with updated access token cookie
          const resBody = await backendRes.text();
          const response = new NextResponse(resBody, {
            status: backendRes.status,
            headers: {
              "Content-Type": backendRes.headers.get("content-type") || "application/json",
            },
          });
          response.cookies.set(ACCESS_TOKEN_COOKIE, accessToken!, {
            httpOnly: true,
            secure: process.env.NODE_ENV === "production",
            sameSite: "lax",
            path: "/",
            maxAge: 60 * 60,
          });
          return response;
        }
      }
    } catch {
      // Fall through to original response
    }
  }

  const resBody = await backendRes.text();
  const response = new NextResponse(resBody, {
    status: backendRes.status,
    headers: {
      "Content-Type": backendRes.headers.get("content-type") || "application/json",
    },
  });

  if (backendRes.status === 401) {
    response.cookies.delete(ACCESS_TOKEN_COOKIE);
    response.cookies.delete(REFRESH_TOKEN_COOKIE);
    response.cookies.delete(USER_ROLE_COOKIE);
  }

  return response;
}

export const GET = handleProxy;
export const POST = handleProxy;
export const PATCH = handleProxy;
export const PUT = handleProxy;
export const DELETE = handleProxy;
