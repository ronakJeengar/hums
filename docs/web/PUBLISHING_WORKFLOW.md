# Publishing Lifecycle & Visibility Workflow

## 1. Overview

Hums enforces a strict distinction between **Media Readiness** (`Track.status`) and **Catalog Visibility** (`Track.is_published`). A track can be fully transcoded and ready for playback without being exposed to public search or discovery.

---

## 2. State Machine Diagram

```
                 ┌───────────────────┐
                 │    UPLOADED       │
                 └─────────┬─────────┘
                           │
                           ▼
                 ┌───────────────────┐
                 │   PROCESSING      │
                 └─────────┬─────────┘
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
   ┌──────────────────────┐   ┌──────────────────────┐
   │       FAILED         │   │        READY         │
   │  (Transcoding Error) │   │ (Media Available)    │
   └──────────┬───────────┘   └──────────┬───────────┘
              │                          │
              │ Retry                    │
              └────────┐                 │
                       ▼                 │
                 ┌───────────┐           │
                 │PROCESSING │           │
                 └───────────┘           │
                                         ▼
                               ┌───────────────────┐
                               │  is_published?    │
                               └─────────┬─────────┘
                                         │
                    ┌────────────────────┴────────────────────┐
                    ▼                                         ▼
        ┌───────────────────────┐                 ┌───────────────────────┐
        │  Draft / Private      │                 │  Public Streaming     │
        │  • is_published=False │                 │  • is_published=True  │
        │  • Visible to Creator │                 │  • Appears in Search  │
        │  • Hidden from Search │                 │  • Appears in Profile │
        └───────────────────────┘                 └───────────────────────┘
                                                              │
                                                              ▼ Moderation Takedown
                                                  ┌───────────────────────┐
                                                  │       MODERATED       │
                                                  │  • Hidden immediately │
                                                  │  • Stream disabled    │
                                                  │  • Audit trail logged │
                                                  └───────────────────────┘
```

---

## 3. Mandatory Invariant Rules

1. **No Publishing Incomplete Media**: A track cannot be published (`is_published = True`) unless `status == READY`. Attempting to publish a track in `UPLOADED`, `PROCESSING`, `FAILED`, or `MODERATED` status triggers an HTTP 400 (`BadRequestError`).
2. **Instant Discovery Isolation**: When `is_published == False`, the track is excluded from:
   - Full-text search queries (`SearchRepository`).
   - Public creator profile discographies (`CreatorRepository.get_creator_profile`).
   - Genre and recommendation feeds.
   - Public audio streaming routes (returns HTTP 404 for unauthenticated or non-owner listeners).
3. **Draft Mode by Default**: New tracks can be uploaded in draft mode, allowing creators to configure artwork, liner notes, and review transcoded renditions before going live.

---

## 4. Moderation & DMCA Takedowns

Platform administrators can intervene at any time by transitioning a track's status to `MODERATED`.
- When a track is `MODERATED`:
  - Streaming is revoked immediately.
  - Public discovery is disabled.
  - An immutable `AdminAuditLog` record is generated recording the admin user ID, track ID, timestamp, and mandatory justification note.
  - Creators are informed via the studio dashboard that the track is under moderation review.
