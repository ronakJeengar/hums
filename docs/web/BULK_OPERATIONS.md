# Bulk Operations Architecture & Resilience

## 1. Overview

Content management at scale requires efficient batch operations. The Hums web platform provides floating bulk action toolbars and backend batch handlers for both creators and administrators.

---

## 2. Permitted Bulk Actions

### Creator Actions (`/api/v1/creator-studio/tracks/bulk-action`)
Creators can perform batch actions strictly scoped to their owned tracks:
- **`publish`**: Set `is_published = True` for selected tracks. (Only tracks with `status == READY` can be published).
- **`unpublish`**: Set `is_published = False` (reverts tracks to draft mode).
- **`retry`**: Re-enqueue Celery transcoding jobs for failed tracks.
- **`update_metadata`**: Batch assign a genre across selected tracks.

### Admin Actions (`/api/v1/admin/tracks/bulk-action`)
Administrators possess elevated bulk capabilities with mandatory audit reason logging:
- **`moderate`**: Transition multiple tracks to `MODERATED`, `READY`, or `FAILED` with an administrative justification note.
- **`publish` / `unpublish`**: Administrative visibility overrides.
- **`retry`**: Re-dispatch transcoding workers across corrupted or failed tracks.

---

## 3. Resilience & Transactional Integrity

Bulk operations follow a **partial-success transactional strategy**:
1. Rather than failing the entire batch if a single item violates a constraint (e.g., trying to publish an un-transcoded track), each item is evaluated independently.
2. The endpoint returns a structured `BulkTrackActionResult`:
```json
{
  "action": "publish",
  "total": 5,
  "succeeded": 4,
  "failed": 1,
  "results": [
    { "track_id": "trk-1", "title": "Track 1", "status": "success", "message": "Published" },
    { "track_id": "trk-2", "title": "Track 2", "status": "failed", "error": "Cannot publish track in PROCESSING status" }
  ]
}
```
3. A modal immediately surfaces the breakdown of succeeded vs. failed tracks, with error details for any failed rows.

---

## 4. UI/UX Interaction Design

- **Multi-Row Checkbox**: Controlled by `@tanstack/react-table` row selection.
- **Floating Contextual Toolbar**: Appears smoothly at the bottom-center of the viewport whenever `selectedTrackIds.length > 0`.
- **Destructive Confirmation**: Moderation actions require specifying a justification note prior to submission.
- **Optimistic Invalidation**: On action completion, TanStack Query invalidates both track tables and dashboard metrics to reflect authoritative backend updates.
