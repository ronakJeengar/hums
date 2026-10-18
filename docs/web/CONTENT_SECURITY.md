# Content Security & Authorization Architecture

## 1. Overview

Hums implements a defense-in-depth security model to protect audio assets, creator intellectual property, and platform integrity across the Next.js web platform and FastAPI backend.

---

## 2. Server-Side Ownership Enforcement

Never trust the client to assert ownership. All mutation and retrieval operations for creators strictly check:
```python
track = await db.scalar(
    select(Track).where(
        Track.id == track_id,
        Track.owner_id == creator.user_id,
    )
)
if not track:
    raise NotFoundError("Track not found")
```
- If a creator attempts to modify, publish, or upload artwork to a track owned by another user, the backend returns HTTP 404 (`NotFoundError`), revealing nothing about the track's existence.
- IDOR (Insecure Direct Object Reference) vulnerabilities are prevented at the SQL layer.

---

## 3. Role-Based Access Control (RBAC)

| Role | Browse Own Tracks | Browse All Tracks | Transcode Retry | Set Published | Upload Artwork | Moderate Takedowns | View Audit Logs |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Creator** | Yes | No | Yes (own) | Yes (own) | Yes (own) | No | No |
| **Admin** | Yes | Yes | Yes (all) | Yes (all) | Yes (all) | Yes | Yes |
| **Superadmin** | Yes | Yes | Yes (all) | Yes (all) | Yes (all) | Yes | Yes |
| **Listener** | No | No | No | No | No | No | No |

- Routes under `/api/v1/creator-studio/` require active `CREATOR`, `ADMIN`, or `SUPERADMIN` credentials.
- Routes under `/api/v1/admin/` require `ADMIN` or `SUPERADMIN` credentials.
- Normal listeners cannot access unpublished or draft tracks under any circumstances.

---

## 4. Media Streaming & Asset Protection

- **No Permanent Public URLs**: Object storage keys are kept internal (e.g. `tracks/{uuid}/master.flac`).
- **Streaming Proxying**: All client playback requests route through `/api/v1/audio/tracks/{id}/stream`.
- **Public Isolation**: The streaming endpoint verifies that `is_published == True` and `status == READY` unless the requester is the authenticated owner or an administrator.
- **Range Request Support**: The stream endpoint supports HTTP `Range: bytes=start-end` headers for fast seeking and playback buffer optimization without transferring unbounded file buffers into memory.

---

## 5. Artwork & File Upload Hardening

- **MIME & Extension Whitelisting**: Artwork uploads strictly accept `image/jpeg`, `image/png`, and `image/webp`. SVG and executable files are blocked.
- **Payload Size Limits**: Artwork files are limited to 5 MB; raw audio uploads are limited to 150 MB.
- **Object Storage Isolation**: Artwork assets are isolated in `artwork/` and audio renditions in `renditions/`.
- **Audit Trails**: Every administrative override, DMCA takedown, and bulk action writes an immutable event into `AdminAuditLog` detailing the actor ID, IP address, target IDs, action type, and required justification.
