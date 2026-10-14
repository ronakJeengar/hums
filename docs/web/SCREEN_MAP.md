# Hums Web Platform — Screen Map & User Journeys

## 1. Authentication & Onboarding

| Route | Role Permitted | Description & Interactions |
| :--- | :--- | :--- |
| `/login` | Public (Anonymous) | Unified login with email/password validation, seed account buttons, error feedback, and dynamic redirection to authorized workspace. |
| `/apply-creator` | `listener` | Self-service application submission to become an artist on Hums, showing current `PENDING` review status. |

---

## 2. Admin Panel Screens

| Route | Minimum Role | Primary Features & Key Actions |
| :--- | :--- | :--- |
| `/admin/dashboard` | `moderator` | High-level metrics (users, creators, tracks, active subscriptions), pending queue counters, and recent immutable audit activity. |
| `/admin/users` | `moderator` (View), `admin` (Actions) | Paginated user directory with role and status filters. Actions: View detail drawer, Suspend/Reactivate user modal, Change platform role modal. |
| `/admin/creators` | `moderator` (View), `admin` (Actions) | Platform artists catalog with track counts and follower counts. Action: Toggle verified artist authenticity badge. |
| `/admin/applications` | `moderator` | Creator applicant queue with audio portfolio links. Actions: Review modal with Approve & Promote to creator, or Reject with notes. |
| `/admin/tracks` | `moderator` | Full catalog content search. Actions: View renditions, Moderate (Takedown) / Restore track with reason, Retry failed transcode jobs. |
| `/admin/reports` | `moderator` | Content violation queue. Actions: Resolve report modal (Set resolution state, action taken, and resolution justification). |
| `/admin/operations` | `admin` | Real-time health probes for PostgreSQL, Redis, Celery, and MinIO storage, plus media transcoding jobs table. |
| `/admin/audit-logs` | `admin` | Immutable compliance log tracking actor, action, target entity, timestamp, reason, and IP address. |

---

## 3. Creator Studio Screens

| Route | Minimum Role | Primary Features & Key Actions |
| :--- | :--- | :--- |
| `/studio/dashboard` | `creator` | Artist overview: Total streams, published tracks, processing tracks, follower counts, top streamed tracks, and recent uploads. |
| `/studio/tracks` | `creator` | Creator's own track catalog. Actions: Edit track metadata modal (title, album, genre, liner notes), Retry processing on failed uploads. |
| `/studio/upload` | `creator` | Audio dropzone supporting FLAC, WAV, MP3, AAC with metadata fields, progress feedback, and Celery transcoding trigger. |
| `/studio/analytics` | `creator` | Recharts listening telemetry: 7d/30d/90d filter, plays timeline area chart, top tracks bar chart, listening entry points breakdown. |
| `/studio/profile` | `creator` | Public artist profile editor: Artist name, biography, avatar image URL, and banner cover URL. |
