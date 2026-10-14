# Hums Web Platform — Authentication & Session Management

## 1. Overview

Hums implements a secure, cookie-based session management strategy built upon the existing FastAPI OAuth2 JWT infrastructure.

---

## 2. Token Storage & Lifecycle

| Cookie Name | Purpose | Flags | Max Age |
| :--- | :--- | :--- | :--- |
| `hums_access_token` | FastAPI Access JWT (role claims, sub) | `HttpOnly`, `SameSite=Lax`, `Path=/`, `Secure` (prod) | 1 hour (3600s) |
| `hums_refresh_token` | Long-lived refresh token for rotation | `HttpOnly`, `SameSite=Lax`, `Path=/`, `Secure` (prod) | 30 days |
| `hums_user_role` | Lightweight client role indicator | `SameSite=Lax`, `Path=/`, `Secure` (prod) | 30 days |

---

## 3. Authentication Flows

### 3.1 Login Flow
1. User enters email and password at `/login`.
2. Browser sends `POST /api/auth/login`.
3. Next.js BFF forwards credentials to FastAPI `POST /api/v1/auth/login`.
4. FastAPI validates argon2/bcrypt password hash and generates an access/refresh token pair with embedded `role` claim.
5. BFF packages tokens into `HttpOnly` response cookies and returns user profile.
6. Client-side router redirects user to their appropriate workspace (`/admin/dashboard` or `/studio/dashboard`).

### 3.2 Transparent Auto-Refresh
When an access token expires:
1. Browser makes request to `/api/proxy/*`.
2. Target returns `401 Unauthorized`.
3. Next.js BFF proxy catches the 401, extracts `hums_refresh_token` from cookies, and calls FastAPI `POST /api/v1/auth/refresh`.
4. FastAPI validates token in `refresh_tokens` database table, rotates the token pair, and issues new tokens.
5. BFF sets the new `hums_access_token` cookie and retries the original request seamlessly.
6. The user experiences zero interruption or unexpected redirects.

### 3.3 Logout Flow
1. User clicks "Logout" in Navbar.
2. Next.js BFF calls FastAPI `POST /api/v1/auth/logout` to revoke the refresh token in PostgreSQL.
3. Next.js BFF clears all session cookies (`hums_access_token`, `hums_refresh_token`, `hums_user_role`).
4. Client redirects to `/login`.
