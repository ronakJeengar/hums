# Changelog

All notable changes to the Hums audio platform are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased] - `feature/security-hardening`

### Added
- **Redis-Backed Rate Limiting (`RateLimiter`):**
  - Atomic pipeline-driven sliding/fixed-window counter enforcing request limits.
  - Attached to authentication endpoints (`/auth/login`, `/auth/register`, `/auth/forgot-password`, `/auth/reset-password`, `/auth/refresh`), playlist creation (`/playlists`), and audio uploads (`/audio/upload`).
  - Returns RFC 6585-compliant `429 Too Many Requests` status code with `Retry-After: {seconds}` header.
  - Graceful fail-open mechanism during transient Redis connectivity interruptions.
- **Defensive HTTP Security Headers Middleware:**
  - Injected `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `X-XSS-Protection: 1; mode=block`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy: camera=(), microphone=(), geolocation=()`.
  - Enforced `Strict-Transport-Security` header in production environments.
- **Production Deployment Validation Guardrails:**
  - Added startup `@model_validator` in `app/core/config.py` halting startup if `SECRET_KEY` is weak (<32 chars or default placeholder), if `DEBUG=True`, or if `CORS_ORIGINS` contains wildcard `*` in production.
  - Conditionally disabled interactive documentation (`/docs`, `/redoc`, `/openapi.json`) when `APP_ENV == "production"`.
- **Bounded Streaming File Uploads (`read_upload_file_bounded`):**
  - Incremental chunk-based stream reader aborting oversized file uploads immediately upon exceeding byte boundaries (audio: 100MB, images: 10MB) to protect against memory exhaustion DoS.
- **Container Least Privilege:**
  - Added non-privileged user `appuser` (UID 1000) to `backend/Dockerfile` with `USER appuser` directive.
- **Mobile Client Production Log Guard:**
  - Added `kReleaseMode` bypass to Flutter `LoggingInterceptor` to suppress network payload logging to Android Logcat and iOS syslogs.
- **Security Test Suite:**
  - Created `backend/tests/test_security.py` with 12 comprehensive automated security test cases.
- **Security Documentation:**
  - Created `docs/security/SECURITY_BASELINE.md`, `docs/security/SECURITY_REPORT.md`, and `docs/security/SECURITY_CHECKLIST.md`.

### Changed
- **Input Boundaries:**
  - Constrained password length to 128 characters on all auth schemas to mitigate hashing CPU starvation.
  - Enforced character bounds on audio metadata fields: `title` (255), `artist_name` (255), `album_name` (255), `genre` (100), `description` (5000).
  - Bounded `PlaylistTracksReorder.track_ids` to maximum 500 items.
- **Playlist Data Integrity:**
  - `PlaylistService.add_track` now validates track processing status and explicitly rejects tracks in `FAILED` status with HTTP 400 `TRACK_FAILED`.
