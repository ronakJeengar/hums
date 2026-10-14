import { cookies } from "next/headers";
import { UserRole } from "@/types";

export const ACCESS_TOKEN_COOKIE = "hums_access_token";
export const REFRESH_TOKEN_COOKIE = "hums_refresh_token";
export const USER_ROLE_COOKIE = "hums_user_role";

export const BACKEND_API_URL =
  process.env.INTERNAL_API_URL ||
  process.env.NEXT_PUBLIC_API_URL ||
  "http://127.0.0.1:8000";

export async function getServerSessionToken(): Promise<string | undefined> {
  const cookieStore = await cookies();
  return cookieStore.get(ACCESS_TOKEN_COOKIE)?.value;
}

export async function getServerRefreshToken(): Promise<string | undefined> {
  const cookieStore = await cookies();
  return cookieStore.get(REFRESH_TOKEN_COOKIE)?.value;
}

export async function getServerUserRole(): Promise<UserRole | undefined> {
  const cookieStore = await cookies();
  return cookieStore.get(USER_ROLE_COOKIE)?.value as UserRole | undefined;
}
