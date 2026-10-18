# Content Library Architecture & Implementation

## 1. Overview

The **Hums Content Library** provides a unified, production-grade media management experience tailored for two distinct personas:
1. **Creators** (`/studio/tracks`): A tenant-isolated media library allowing verified artists and creators to search, filter, paginate, inspect, edit, and bulk-manage their own audio tracks.
2. **Administrators** (`/admin/tracks`): A global catalog supervision and moderation interface providing cross-tenant search, creator ownership inspection, transcoding diagnostics, status overrides, and audit trails.

Both interfaces sit on top of the shared **FastAPI backend** and authoritative PostgreSQL records, ensuring zero client-side state divergence or duplicated business logic.

---

## 2. Media Library Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Next.js Web Client                              │
│                                                                        │
│   Creator Studio (/studio/tracks)       Admin Console (/admin/tracks)  │
│   • Multi-select checkboxes             • Multi-select checkboxes      │
│   • Genre / Status / Publish filters    • Owner / Status / Publish     │
│   • Artwork thumbnails & metadata       • Global moderation overrides  │
│   • Floating bulk action toolbar        • Floating bulk moderation     │
└───────────────────▲──────────────────────────────────▲─────────────────┘
                    │                                  │
                    │ JSON (TanStack Query)            │ JSON (TanStack Query)
                    ▼                                  ▼
┌────────────────────────────────────────────────────────────────────────┐
│                           FastAPI Backend                              │
│                                                                        │
│   GET /api/v1/creator-studio/tracks     GET /api/v1/admin/tracks       │
│   POST /api/v1/creator-studio/tracks/   POST /api/v1/admin/tracks/     │
│        bulk-action                           bulk-action               │
└───────────────────▲──────────────────────────────────▲─────────────────┘
                    │                                  │
                    ▼                                  ▼
┌────────────────────────────────────────────────────────────────────────┐
│                     PostgreSQL & Object Storage                        │
│                                                                        │
│   • Track (owner_id, status, is_published, cover_image_key)            │
│   • AudioRendition (128kbps, 192kbps, 320kbps AAC/MP3)                │
│   • AudioProcessingJob (attempts, error_message, state)               │
│   • AdminAuditLog (actor_id, target_id, action, reason)               │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Data Tables, Filtering, Sorting & Pagination

### TanStack Table Integration
The table leverages `@tanstack/react-table` (v8) wrapped inside the reusable `<DataTable />` component (`web/src/components/ui/data-table.tsx`).

Key capabilities:
- **Row Selection**: Native `enableRowSelection: true` with controlled `rowSelection` state and stable row keys (`getRowId: (row) => row.id`).
- **Server-Side Pagination**: Pages (`page`, `size: 20`) are forwarded directly to PostgreSQL `LIMIT` and `OFFSET` clauses.
- **Dynamic Sorting**: Multi-field sorting by `created_at`, `title`, `play_count`, `likes_count`, and `duration_seconds` in `asc` or `desc` directions.
- **Multi-Faceted Filtering**:
  - Processing status: `ALL`, `READY`, `PROCESSING`, `FAILED`, `MODERATED`, `UPLOADED`.
  - Publishing lifecycle: `ALL`, `published` (`is_published == True`), `unpublished` (`is_published == False`).
  - Genre classification: 13 standardized genre buckets.
  - Case-insensitive search on track title, artist name, and album name.

---

## 4. Multi-Tenant Isolation

### Server-Side Ownership Enforcement
Isolation is enforced at the repository and database query level:
- In `CreatorStudioRepository.list_tracks(creator_id, ...)`:
  Every query is hard-scoped with `select(Track).where(Track.owner_id == creator.user_id)`.
- In `CreatorStudioRepository.get_track_detail(track_id, creator_id)`:
  The track is retrieved with `Track.id == track_id` and `Track.owner_id == creator.user_id`. Attempting to access another creator's track immediately yields an HTTP 404 (`NotFoundError`), concealing track existence from unauthorized actors.

### Admin Cross-Tenant Supervision
Administrators possess elevated permissions (`ADMIN` or `SUPERADMIN`). `AdminRepository.list_tracks(...)` joins `Track` with `User` and `CreatorProfile` to provide authoritative creator attribution while retaining filter capabilities across the entire multi-tenant catalog.
