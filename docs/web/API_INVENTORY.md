# Hums Web Platform — API Inventory

This document provides a comprehensive mapping of every screen in the **Admin Panel** and **Creator Studio** to its authoritative FastAPI backend endpoint, including schemas, authorization rules, and pagination.

---

## 1. Authentication & Session Management

| Screen / Flow | Method | Endpoint | Request Schema | Response Schema | Auth | Permissions | Pagination / Filtering | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Login Screen** | `POST` | `/api/v1/auth/login` | `UserLogin` | `ApiResponse[AuthResponse]` | Public | None | None | Issues access token (30m) & refresh token (7d). BFF stores in HttpOnly cookies. |
| **BFF Session Check** | `GET` | `/api/v1/users/me` | None | `ApiResponse[UserRead]` | Bearer | Any active user | None | Validates active session and retrieves user profile with role (`admin`, `moderator`, `creator`, `listener`). |
| **Token Refresh** | `POST` | `/api/v1/auth/refresh` | `RefreshTokenRequest` | `ApiResponse[TokenResponse]` | Public | Valid refresh token | None | Atomic token rotation with hash invalidation. |
| **Logout** | `POST` | `/api/v1/auth/logout` | `LogoutRequest` | `ApiResponse[dict]` | Optional Bearer | Any | None | Revokes refresh token in database; BFF clears session cookies. |

---

## 2. Admin Panel Screens

### 2.1 Admin Dashboard

| Metric / Widget | Method | Endpoint | Request Schema | Response Schema | Auth | Permissions | Pagination / Filtering | Backend Capability |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Overview Metrics & KPIs** | `GET` | `/api/v1/admin/dashboard` | None | `ApiResponse[AdminDashboardStats]` | Bearer | `admin`, `moderator` | None | **NEW**: Aggregates total users, active users (30d), total creators, published tracks, failed uploads, pending applications, pending reports, subscriptions breakdown. |

### 2.2 User Management

| Screen Action | Method | Endpoint | Request Schema | Response Schema | Auth | Permissions | Pagination / Filtering | Backend Capability |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **List Users Table** | `GET` | `/api/v1/admin/users` | None | `ApiResponse[PaginatedResponse[AdminUserItem]]` | Bearer | `admin`, `moderator` | `page`, `size`, `search`, `role`, `status` | **NEW**: Search by email/name/username, filter by role/active state. |
| **User Details Drawer** | `GET` | `/api/v1/admin/users/{user_id}` | None | `ApiResponse[AdminUserDetail]` | Bearer | `admin`, `moderator` | None | **NEW**: Returns full user info, uploaded tracks summary, subscription details, creator profile status. |
| **Suspend / Activate User** | `PATCH` | `/api/v1/admin/users/{user_id}/status` | `UpdateUserStatusRequest` | `ApiResponse[AdminUserItem]` | Bearer | `admin` | None | **NEW**: Updates `is_active`, records `suspension_reason` and `suspended_at`, generates audit log. |
| **Update User Role** | `PATCH` | `/api/v1/admin/users/{user_id}/role` | `UpdateUserRoleRequest` | `ApiResponse[AdminUserItem]` | Bearer | `admin` | None | **NEW**: Elevates/demotes between `listener`, `creator`, `moderator`, `admin`. Generates audit log. |

### 2.3 Creator Management & Applications

| Screen Action | Method | Endpoint | Request Schema | Response Schema | Auth | Permissions | Pagination / Filtering | Backend Capability |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Creator Directory Table** | `GET` | `/api/v1/admin/creators` | None | `ApiResponse[PaginatedResponse[AdminCreatorItem]]` | Bearer | `admin`, `moderator` | `page`, `size`, `search` | **NEW**: Lists creators with track count, total plays, followers, verification state. |
| **Verify Creator** | `PATCH` | `/api/v1/admin/creators/{creator_id}/verify` | `VerifyCreatorRequest` | `ApiResponse[AdminCreatorItem]` | Bearer | `admin` | None | **NEW**: Toggles `is_verified` badge, logs audit event. |
| **Applications Queue** | `GET` | `/api/v1/admin/creator-applications` | None | `ApiResponse[PaginatedResponse[CreatorApplicationItem]]` | Bearer | `admin`, `moderator` | `page`, `size`, `status` | **NEW**: Lists applicant submissions (`PENDING`, `APPROVED`, `REJECTED`). |
| **Review Application** | `PATCH` | `/api/v1/admin/creator-applications/{app_id}` | `ReviewApplicationRequest` | `ApiResponse[CreatorApplicationItem]` | Bearer | `admin`, `moderator` | None | **NEW**: Approves (auto-creates `Creator` entity & assigns `creator` role) or rejects with review notes. |

### 2.4 Content Management & Moderation

| Screen Action | Method | Endpoint | Request Schema | Response Schema | Auth | Permissions | Pagination / Filtering | Backend Capability |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **All Tracks Table** | `GET` | `/api/v1/admin/tracks` | None | `ApiResponse[PaginatedResponse[AdminTrackItem]]` | Bearer | `admin`, `moderator` | `page`, `size`, `search`, `status`, `genre` | **NEW**: Search tracks across catalog, filter by processing/moderation status. |
| **Track Detail & Audio** | `GET` | `/api/v1/admin/tracks/{track_id}` | None | `ApiResponse[AdminTrackDetail]` | Bearer | `admin`, `moderator` | None | **NEW**: Full track metadata, processing jobs history, renditions list, moderation flags. |
| **Moderate Track** | `PATCH` | `/api/v1/admin/tracks/{track_id}/status` | `ModerateTrackRequest` | `ApiResponse[AdminTrackItem]` | Bearer | `admin`, `moderator` | None | **NEW**: Updates status (`READY`, `MODERATED`, `FAILED`), stores moderation reason, logs audit event. |
| **Retry Transcoding** | `POST` | `/api/v1/admin/tracks/{track_id}/retry` | None | `ApiResponse[dict]` | Bearer | `admin`, `moderator` | None | **NEW**: Dispatches Celery transcoding task `app.workers.tasks.transcode_audio_track`. |

### 2.5 Reports & Moderation

| Screen Action | Method | Endpoint | Request Schema | Response Schema | Auth | Permissions | Pagination / Filtering | Backend Capability |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Content Report Queue** | `GET` | `/api/v1/admin/reports` | None | `ApiResponse[PaginatedResponse[ContentReportItem]]` | Bearer | `admin`, `moderator` | `page`, `size`, `status`, `reason`, `entity_type` | **NEW**: Lists reported tracks/creators/users. |
| **Report Details** | `GET` | `/api/v1/admin/reports/{report_id}` | None | `ApiResponse[ContentReportDetail]` | Bearer | `admin`, `moderator` | None | **NEW**: Fetches report info, reporter details, target entity snapshot. |
| **Resolve / Dismiss Report**| `PATCH` | `/api/v1/admin/reports/{report_id}` | `ResolveReportRequest` | `ApiResponse[ContentReportItem]` | Bearer | `admin`, `moderator` | None | **NEW**: Sets status (`RESOLVED`, `DISMISSED`), action taken (`NO_ACTION`, `TRACK_REMOVED`, `USER_SUSPENDED`), resolution notes. |

### 2.6 Platform Operations & Health

| Screen Action | Method | Endpoint | Request Schema | Response Schema | Auth | Permissions | Pagination / Filtering | Backend Capability |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Services Health** | `GET` | `/api/v1/admin/operations/health` | None | `ApiResponse[SystemHealthStatus]` | Bearer | `admin` | None | **NEW**: Checks PostgreSQL, Redis, Celery broker, MinIO storage live health with response latencies. |
| **Recent Failed Jobs** | `GET` | `/api/v1/admin/operations/jobs` | None | `ApiResponse[PaginatedResponse[ProcessingJobItem]]` | Bearer | `admin` | `page`, `size`, `status` | **NEW**: Lists media processing jobs (`PENDING`, `PROCESSING`, `COMPLETED`, `FAILED`) with errors. |

### 2.7 Audit Logs

| Screen Action | Method | Endpoint | Request Schema | Response Schema | Auth | Permissions | Pagination / Filtering | Backend Capability |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Administrative Activity**| `GET` | `/api/v1/admin/audit-logs` | None | `ApiResponse[PaginatedResponse[AdminAuditLogItem]]` | Bearer | `admin` | `page`, `size`, `action`, `target_type`, `search` | **NEW**: Immutable event log with actor, action, target, timestamp, reason, IP address. |

---

## 3. Creator Studio Screens

### 3.1 Creator Dashboard

| Screen Action | Method | Endpoint | Request Schema | Response Schema | Auth | Permissions | Pagination / Filtering | Backend Capability |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Creator Overview** | `GET` | `/api/v1/creator-studio/dashboard` | None | `ApiResponse[CreatorDashboardStats]` | Bearer | `creator`, `admin` | None | **NEW**: Returns published tracks count, processing tracks, failed uploads, total plays, followers count, top tracks, recent uploads. |

### 3.2 Track Management

| Screen Action | Method | Endpoint | Request Schema | Response Schema | Auth | Permissions | Pagination / Filtering | Backend Capability |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **My Tracks Table** | `GET` | `/api/v1/creator-studio/tracks` | None | `ApiResponse[PaginatedResponse[CreatorTrackItem]]` | Bearer | `creator`, `admin` | `page`, `size`, `status`, `search` | **NEW**: Lists tracks owned by the authenticated creator with status, duration, likes, plays. |
| **Edit Track Metadata** | `PATCH` | `/api/v1/creator-studio/tracks/{track_id}` | `UpdateTrackRequest` | `ApiResponse[CreatorTrackItem]` | Bearer | `creator`, `admin` (Owner only) | None | **NEW**: Allows updating title, artist_name, album_name, genre, description. Checks track ownership. |
| **Retry Processing** | `POST` | `/api/v1/creator-studio/tracks/{track_id}/retry` | None | `ApiResponse[dict]` | Bearer | `creator`, `admin` (Owner only) | None | **NEW**: Retries transcoding on creator's own failed track. |
| **Delete Track** | `DELETE` | `/api/v1/creator-studio/tracks/{track_id}` | None | `ApiResponse[dict]` | Bearer | `creator`, `admin` (Owner only) | None | Existing `DELETE /api/v1/audio/{id}` can be reused or aliased. |
| **Initiate Audio Upload** | `POST` | `/api/v1/audio/upload` | Multipart form | `ApiResponse[TrackUploadResponse]` | Bearer | Any uploader | None | Reuses existing production upload pipeline (validates file, writes to S3, dispatches Celery job). |

### 3.3 Creator Analytics

| Screen Action | Method | Endpoint | Request Schema | Response Schema | Auth | Permissions | Pagination / Filtering | Backend Capability |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Analytics Aggregation**| `GET` | `/api/v1/creator-studio/analytics` | None | `ApiResponse[CreatorAnalyticsResponse]` | Bearer | `creator`, `admin` | `period` (`7d`, `30d`, `90d`) | **NEW**: Aggregates `playback_events` for creator's tracks grouped by day, top tracks by plays, listening sources breakdown. |

### 3.4 Creator Profile

| Screen Action | Method | Endpoint | Request Schema | Response Schema | Auth | Permissions | Pagination / Filtering | Backend Capability |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Get Studio Profile** | `GET` | `/api/v1/creator-studio/profile` | None | `ApiResponse[CreatorStudioProfile]` | Bearer | `creator`, `admin` | None | **NEW**: Returns creator's profile, bio, handle, artwork URLs, follower stats. |
| **Update Studio Profile**| `PATCH` | `/api/v1/creator-studio/profile` | `UpdateCreatorProfileRequest` | `ApiResponse[CreatorStudioProfile]` | Bearer | `creator`, `admin` | None | **NEW**: Updates artist name, bio, cover image URL, avatar URL. |

### 3.5 Creator Application (Listener Flow)

| Screen Action | Method | Endpoint | Request Schema | Response Schema | Auth | Permissions | Pagination / Filtering | Backend Capability |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Submit Application** | `POST` | `/api/v1/creator-applications` | `CreateCreatorApplicationRequest` | `ApiResponse[CreatorApplicationItem]` | Bearer | `listener` | None | **NEW**: Non-creators submit application to join creator program. |
| **Check My Application** | `GET` | `/api/v1/creator-applications/me` | None | `ApiResponse[Optional[CreatorApplicationItem]]` | Bearer | Any user | None | **NEW**: Checks current pending/approved/rejected status. |
