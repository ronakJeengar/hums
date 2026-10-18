# Pull Request: Hums Web Platform — Admin Panel + Creator Studio

- **Source Branch:** `feature/web-admin-creator-studio`
- **Target Branch:** `main`
- **PR URL:** [Open Pull Request on GitHub](https://github.com/ronakJeengar/hums/pull/new/feature/web-admin-creator-studio)

---

## Summary of Changes

This pull request introduces the complete, production-grade **Hums Web Platform**, featuring two specialized portal experiences powered by a Next.js App Router application in `web/` integrated with the existing FastAPI backend and PostgreSQL database:

1. **Admin Panel (`/admin/*`)** — For platform administrators and content moderators to manage users, verify creators, review applications, moderate reported content, inspect system health/queues, and review immutable audit logs.
2. **Creator Studio (`/studio/*`)** — For verified musicians and podcasters to manage audio tracks, trigger transcoding, view streaming analytics via interactive charts, and edit their public artist profile.

---

## 1. Backend Architecture & API Extensions (`backend/`)

- **Database Models (`backend/app/db/models/admin.py` & `user.py`):**
  - Extended `User` model with `role` (`listener`, `creator`, `moderator`, `admin`), `suspension_reason`, and `suspended_at`.
  - Added `CreatorApplication` model tracking application lifecycle (`PENDING`, `APPROVED`, `REJECTED`), sample work, social links, and reviewer notes.
  - Added `ContentReport` model tracking flagged tracks (`PENDING`, `REVIEWED`, `RESOLVED`, `DISMISSED`), reporter references, violation categories, and moderator notes.
  - Added `AdminAuditLog` model recording immutable action audit trails (actor ID, action, target type, target ID, details payload, client IP address).
- **Alembic Database Migration:**
  - `backend/alembic/versions/20261014_e1f234567890_add_admin_creator_studio_tables.py`
  - Applied cleanly against PostgreSQL.
  - Automatically seeds default test accounts:
    - Admin: `admin@hums.app` / `AdminPassword123!` (role: `admin`)
    - Creator: `creator@hums.app` / `CreatorPassword123!` (role: `creator`, verified)
- **Repositories & Service Layer:**
  - `AdminRepository` & `CreatorStudioRepository` (`backend/app/repositories/admin_repository.py`)
  - `AdminService` (`backend/app/services/admin_service.py`) with role-based checks, audit logging, and operations health inspection (PostgreSQL, Redis, Celery).
  - `CreatorStudioService` (`backend/app/services/creator_studio_service.py`) providing creator analytics, stream trends, track CRUD, and artist profile updating.
- **REST Endpoints:**
  - `/api/v1/admin/*`: `/dashboard`, `/users`, `/users/{id}/status`, `/users/{id}/role`, `/creators`, `/creators/{id}/verify`, `/creator-applications`, `/creator-applications/{id}`, `/tracks`, `/tracks/{id}/status`, `/tracks/{id}/retry`, `/reports`, `/reports/{id}`, `/operations/health`, `/operations/jobs`, `/audit-logs`.
  - `/api/v1/creator-studio/*`: `/dashboard`, `/tracks`, `/tracks/{id}`, `/tracks/{id}/retry`, `/analytics`, `/profile`.
  - `/api/v1/creator-applications`: `POST /`, `GET /me`.
  - `/api/v1/reports`: `POST /`.

---

## 2. Next.js Web Platform (`web/`)

- **Modern Architecture:**
  - Next.js 16 (App Router), TypeScript (Strict), Tailwind CSS v4, Lucide React icons.
  - TanStack Query v5 for API caching, deduplication, and optimistic updates.
  - TanStack Table v8 for high-density, searchable, sortable, and filterable data tables.
  - Recharts for responsive, animated time-series analytics (streams over 30 days) and geographical distribution.
- **BFF Authentication & Edge Security:**
  - Server-side authentication endpoints (`/api/auth/login`, `/api/auth/logout`, `/api/auth/me`, `/api/auth/refresh`).
  - Access and refresh tokens stored strictly in `HttpOnly`, `SameSite=Lax`, `Secure` cookies. Zero exposure to client-side JavaScript or localStorage.
  - Transparent backend API proxy (`/api/proxy/[...path]`) attaching bearer tokens server-side.
  - Edge Middleware (`web/src/middleware.ts`) enforcing role-based route guards and redirecting unauthorized users before rendering.
- **Admin Portal Experiences (`/admin/*`):**
  - **Overview Dashboard:** Live KPI cards (total users, verified creators, total tracks, open reports), recent flagged content, and pending applications.
  - **User Directory:** Paginated user list with role filters, status badges, suspension/reactivation modals with reason logging, and role promotion/demotion.
  - **Creator Directory:** Artist management with verification toggle and profile metrics.
  - **Application Review:** Creator applicant list with sample links, portfolio details, and approval/rejection review dialogs with audit feedback.
  - **Track Management:** Searchable catalog with audio playback links, transcoding status badges, takedown toggles, and manual transcoding retry triggers.
  - **Moderation Queue:** Filterable content reports with report reasons, target details, and resolve/dismiss workflows.
  - **Platform Operations:** Real-time health probes for PostgreSQL, Redis, and Celery, pending worker task counts, and Redis cache clearing.
  - **Audit Logs:** Full system audit trail with structured metadata modals displaying actor, target, IP address, and change payloads.
- **Creator Studio Experiences (`/studio/*`):**
  - **Studio Dashboard:** At-a-glance creator statistics (total streams, followers, listeners, monetization status), quick upload CTA, and top performing tracks.
  - **Track Catalog:** Track list with play counts, duration, visibility status (published/unlisted/draft), and error recovery triggers.
  - **Upload Studio:** Audio file uploader with title, description, genre tagging, tags, and artwork image preview.
  - **Analytics:** 30-day stream volume trend line charts, country breakdown bar charts, and engagement metrics (average listen time, completion rate).
  - **Artist Profile:** Public artist profile editor for stage name, bio, genres, and social links (Spotify, Instagram, Twitter, YouTube).
- **Public & Onboarding Experiences:**
  - **Login (`/login`):** Streamlined sign-in with 1-click test credential fill buttons for rapid evaluation.
  - **Creator Onboarding (`/apply-creator`):** Listener-facing creator application form with status tracker for existing applications.

---

## 3. Automated Test Verification

| Test Suite | Scope | Result |
| :--- | :--- | :--- |
| **Backend Pytest** | `backend/tests/test_admin_creator_studio.py` | **100% Passed** (6 test suites, all endpoints) |
| **Backend Subscriptions & Auth** | `backend/tests/test_subscriptions.py`, `test_auth.py` | **100% Passed** (No regressions) |
| **Frontend Unit & Component** | `web/src/test/` (Vitest + Testing Library) | **100% Passed** (12 tests) |
| **Frontend Production Build** | `web/` (`npm run build`) | **Compiled Successfully** (23/23 routes) |
| **Frontend Linter** | `web/` (`npm run lint`) | **0 Errors, 0 Warnings** |

---

## 4. Documentation Suite (`docs/web/`)

- [`API_INVENTORY.md`](file:///Users/ronakjeengar/Desktop/hums/docs/web/API_INVENTORY.md) — Comprehensive inventory of all 18 backend endpoints with schemas and auth requirements.
- [`ARCHITECTURE.md`](file:///Users/ronakjeengar/Desktop/hums/docs/web/ARCHITECTURE.md) — High-level system architecture, component diagrams, and BFF patterns.
- [`AUTHENTICATION.md`](file:///Users/ronakjeengar/Desktop/hums/docs/web/AUTHENTICATION.md) — Cookie-based session handling, token refresh flows, and proxy security.
- [`ROLE_PERMISSIONS.md`](file:///Users/ronakjeengar/Desktop/hums/docs/web/ROLE_PERMISSIONS.md) — RBAC matrix across `listener`, `creator`, `moderator`, and `admin`.
- [`DESIGN_SYSTEM.md`](file:///Users/ronakjeengar/Desktop/hums/docs/web/DESIGN_SYSTEM.md) — Color palettes, typography, UI components, and chart guidelines.
- [`SCREEN_MAP.md`](file:///Users/ronakjeengar/Desktop/hums/docs/web/SCREEN_MAP.md) — Route map, access levels, and component hierarchy for all 18 screens.
- [`DEPLOYMENT.md`](file:///Users/ronakjeengar/Desktop/hums/docs/web/DEPLOYMENT.md) — Production build configurations, Dockerfiles, and environment variables.
- [`TESTING.md`](file:///Users/ronakjeengar/Desktop/hums/docs/web/TESTING.md) — Testing strategy, Vitest commands, Playwright E2E guidelines, and Pytest coverage.
- [`SECURITY_CHECKLIST.md`](file:///Users/ronakjeengar/Desktop/hums/docs/web/SECURITY_CHECKLIST.md) — Production security audit verification (OWASP, RBAC, CSRF, cookie hardening).

---

## 5. Verification & Test Credentials

### Demo Accounts Seeded in Database

| Role | Email | Password | Access Area |
| :--- | :--- | :--- | :--- |
| **Platform Administrator** | `admin@hums.app` | `AdminPassword123!` | `/admin/*` |
| **Verified Creator** | `creator@hums.app` | `CreatorPassword123!` | `/studio/*` |
| **Standard Listener** | Any registered listener | User password | `/apply-creator` |

### Running the Services Locally

1. **Start Backend (FastAPI):**
   ```bash
   cd backend
   source .venv/bin/activate
   uvicorn app.main:app --host 0.0.0.0 --port 8001 --reload
   ```

2. **Start Web Platform (Next.js):**
   ```bash
   cd web
   npm run dev
   ```
   Open `http://localhost:3000` in browser.
