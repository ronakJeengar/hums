# Hums Web Platform — Architecture & Systems Design

## 1. Executive Summary

The **Hums Web Platform** provides a dual-experience enterprise web application for the Hums high-fidelity audio streaming ecosystem:
1. **Admin Panel** (`/admin/*`) — Dedicated workspace for authorized platform administrators and moderators to manage users, evaluate creator applications, enforce content moderation/takedowns, monitor infrastructure health, and inspect immutable audit logs.
2. **Creator Studio** (`/studio/*`) — Dedicated workspace for approved artists and creators to upload master audio, edit track metadata, analyze playback trends, and manage artist identity.

The web platform is built with **Next.js 16 (App Router)**, **TypeScript** (strict mode), **Tailwind CSS v4**, **TanStack Query v5**, **TanStack Table v8**, and **Recharts**, connecting to the existing **FastAPI** backend via an architectural Backend-For-Frontend (BFF) proxy pattern.

---

## 2. Architecture Overview

```
                      +---------------------------------------+
                      |               Client                  |
                      |   (Browser / Next.js React SPA)       |
                      +---------------------------------------+
                                          |
                      Same-Origin HTTP Requests + SameSite Cookies
                                          |
                                          v
                      +---------------------------------------+
                      |         Next.js App Router BFF        |
                      |---------------------------------------|
                      | - Edge Middleware (Route Guards)      |
                      | - Auth Handlers (/api/auth/*)         |
                      | - Proxy Gateway (/api/proxy/*)        |
                      | - HttpOnly Cookie Session Management  |
                      | - Auto-Refresh Token Rotation         |
                      +---------------------------------------+
                                          |
                             Bearer JWT Authorization
                                          |
                                          v
                      +---------------------------------------+
                      |            FastAPI Backend            |
                      |---------------------------------------|
                      | - /api/v1/admin/*                     |
                      | - /api/v1/creator-studio/*            |
                      | - /api/v1/creator-applications/*      |
                      | - /api/v1/reports/*                   |
                      | - /api/v1/audio/*                     |
                      +---------------------------------------+
                             |                     |
                             v                     v
                +-----------------------+  +-------------------+
                | PostgreSQL (Port 5434)|  | Redis / Celery    |
                | - Users, Creators     |  | - Transcode Jobs  |
                | - Tracks, Renditions  |  | - Cache           |
                | - Audit Logs, Reports |  | - S3 / MinIO      |
                +-----------------------+  +-------------------+
```

---

## 3. Core Architectural Principles

### 3.1 Backend-First & Single Source of Truth
- **Zero Mock Fixtures:** All metrics, users, tracks, applications, and playback events represent real, verified records in the PostgreSQL database.
- **Server-Side Enforcement:** Authorization is validated authoritatively by FastAPI dependency injections (`require_admin_role`, `require_moderator_or_admin_role`, `require_creator_role`). Client-side checks are UX-only; no client claim can bypass backend authorization.

### 3.2 Backend-For-Frontend (BFF) Security Pattern
- JWT Access and Refresh Tokens are stored exclusively in **`HttpOnly`**, **`Secure`**, **`SameSite=Lax`** cookies.
- No JavaScript code in the browser has access to raw JWT tokens, neutralizing Cross-Site Scripting (XSS) token theft vulnerabilities.
- Next.js Edge Middleware (`middleware.ts`) inspects the session role at the edge to block unauthorized navigation before components render.
- The Next.js API Proxy (`/api/proxy/[...path]`) attaches the `Authorization: Bearer <token>` header server-to-server and transparently handles token refresh if an access token expires.

### 3.3 Server & Client State Management
- **Server State:** Managed by **TanStack Query** (`@tanstack/react-query`). Queries are configured with a 30-second stale time, background refetching, and targeted query invalidation on mutation success.
- **Data Tables:** Powered by **TanStack Table** with server-side pagination, search debouncing, and stateful filters.
- **Visualizations:** Visualized via **Recharts** with responsive container sizing and gradient-filled area charts.
