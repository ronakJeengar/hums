# Hums Web Platform — Testing Strategy & Verification Guide

## 1. Test Architecture

The Hums Web Platform employs a two-tier testing strategy:
1. **Backend Integration & Unit Tests (Python/Pytest):** Verifies all FastAPI endpoints, role authorization guards, database aggregations, and Celery retries.
2. **Frontend Component & Unit Tests (Vitest & React Testing Library):** Verifies role permissions, formatting helpers, and UI component rendering.

---

## 2. Running Backend Tests

```bash
cd backend
source .venv/bin/activate
pytest tests/test_admin_creator_studio.py -v
```

### Verified Scenarios:
- `test_admin_access_control`: 401 unauthenticated, 403 listener, 200 admin.
- `test_admin_user_management`: Listing users, viewing detail, updating roles, account suspension, audit logging.
- `test_creator_application_lifecycle`: Application submission, status check, administrative review, automatic promotion to creator.
- `test_content_reporting_and_resolution`: Community report submission, queue filtering, resolution with action taken.
- `test_creator_studio_capabilities`: Role guard (403 listener), dashboard stats, tracks list, analytics aggregation, profile update.
- `test_system_operations_health`: Real-time health check probes (Postgres, Redis, Celery, Storage).

---

## 3. Running Frontend Tests

```bash
cd web
npm test
```

### Verified Scenarios:
- `src/test/permissions.test.ts`:
  - Role hierarchy validation (`admin` > `moderator` > `creator` > `listener`).
  - Access control helpers (`canAccessAdmin`, `canAccessStudio`, `canManageUsers`, `canModerateContent`).
  - Role-based default destination routes.
- `src/test/utils.test.ts`:
  - `formatDuration`: Validates mm:ss conversions for audio lengths.
  - `formatNumber`: Validates thousands grouping.
  - `cn`: Validates Tailwind class merging.
- `src/test/components.test.tsx`:
  - `<Button />`: Label rendering, loading spinner, disabled state.
  - `<StatusBadge />`: Semantic badge colors across statuses.
  - `<StatCard />`: KPI formatting and trend indicator pills.

---

## 4. Linting & Type Checking

```bash
cd web
npm run lint
npm run build
```

Verifies zero TypeScript errors and zero ESLint errors.
