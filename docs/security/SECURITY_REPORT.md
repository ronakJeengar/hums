# Hums — Production Security Hardening Report

**Feature:** `feature/security-hardening`  
**Date:** September 2026  
**Auditor / Engineer:** Senior Application Security Engineer  
**Baseline Git Revision:** `81c4d06`  
**Status:** Completed & Verified

---

## 1. Executive Summary

This report documents the security audit, vulnerability analysis, and defensive hardening implemented across the **Hums** high-fidelity audio streaming and podcast platform. The hardening pass evaluated the FastAPI backend, PostgreSQL relational database, Redis cache and message broker, Celery worker infrastructure, FFmpeg transcode processing, MinIO object storage, Docker containerization, and the Flutter mobile application.

All identified vulnerabilities and exposure risks were remediated without degrading system performance, altering core application behavior, or introducing breaking API changes. 100% of the regression and security test suites pass (86 backend tests and 119 mobile unit/widget tests), and zero vulnerabilities were identified in the Python package dependency audit.

---

## 2. Threat Model & Security Posture Assessment

The threat model was constructed around six core attack vectors:
1. **Denial of Service (DoS) via Unbounded Payloads & Memory Starvation:** Attackers transmitting gigabyte-scale audio or image streams into memory (`await file.read()`), causing OOM crashes of the backend ASGI worker processes.
2. **Credential Stuffing & Brute-Force Attacks:** Unthrottled authentication endpoints (`/auth/login`, `/auth/register`, `/auth/forgot-password`) vulnerable to dictionary attacks and distributed brute force.
3. **Insecure Production Deployment Configurations:** Unvalidated environment variables allowing applications to boot in production with default secrets, wildcard CORS (`*`), or active interactive API documentation exposing internal schemas.
4. **Broken Object-Level Authorization (BOLA / IDOR):** Malicious authenticated users attempting to view, mutate, or delete private playlists, drafts, or media belonging to other users.
5. **Container Privilege Escalation:** Application container images running as `root`, facilitating host escalation in the event of an arbitrary code execution vulnerability in native C-dependencies (such as FFmpeg).
6. **Mobile Data Leakage:** Overly verbose logging interceptors printing request/response bodies containing tokens, passwords, and sensitive metadata into Android Logcat and iOS syslogs.

---

## 3. Vulnerability Findings & Defensive Hardening Implemented

### 3.1. Atomic Redis-Backed Rate Limiting (`CWE-799`, `CWE-307`)
* **Finding:** Key authentication and creation endpoints were unthrottled, allowing attackers to perform high-frequency dictionary attacks on passwords or flood database tables with junk accounts and playlists.
* **Remediation:** 
  - Designed and implemented a non-blocking, Redis-backed sliding/fixed-window rate limiter dependency (`app/core/rate_limit.py`).
  - Utilizes atomic Redis pipeline operations (`INCR` + `EXPIRE` / `TTL`) to eliminate race conditions.
  - Automatically identifies clients via SHA-256 token hash prefix (for authenticated requests) or client IP (for unauthenticated endpoints).
  - Implements graceful fail-open resilience: if Redis suffers a transient outage, the application logs a warning and allows requests through without cascading service failure.
  - Returns RFC 6585-compliant `429 Too Many Requests` responses with `Retry-After: {seconds}` header.
  - Attached to:
    - `POST /api/v1/auth/login`: 15 req/min
    - `POST /api/v1/auth/register`: 10 req/min
    - `POST /api/v1/auth/forgot-password`: 5 req/min
    - `POST /api/v1/auth/reset-password`: 10 req/min
    - `POST /api/v1/auth/refresh`: 30 req/min
    - `POST /api/v1/playlists`: 30 req/min
    - `POST /api/v1/audio/upload`: 10 req/min

### 3.2. Bounded Streaming Uploads & Memory DoS Prevention (`CWE-400`, `CWE-770`)
* **Finding:** File upload endpoints (`/audio/upload`, `/playlists/{id}/cover`, `/profile/avatar`) read the entire file payload into memory using unbounded `await file.read()`. An attacker uploading multiple 500MB+ files concurrently could starve host RAM and crash the Uvicorn worker process.
* **Remediation:**
  - Implemented `read_upload_file_bounded(file, max_bytes)` utility (`app/utils/upload.py`) that reads chunks (64KB) incrementally.
  - Aborts the connection and raises an immediate `400 Bad Request` with `FILE_TOO_LARGE` code as soon as incoming bytes exceed the threshold, before memory is exhausted.
  - Applied to audio uploads (max 100MB), playlist covers (max 10MB), and user avatars (max 10MB).

### 3.3. Input Boundary Enforcement (`CWE-20`)
* **Finding:** String inputs across metadata and authentication lacked strict upper bounds, risking Postgres string truncation exceptions, regex evaluation overhead, or bcrypt/argon2 hashing CPU starvation attacks (e.g. sending a 5MB password string).
* **Remediation:**
  - Added strict Pydantic field constraints across `UserLogin`, `RegisterRequest`, `UserCreate`, `ResetPasswordRequest`, `RefreshTokenRequest`, and `LogoutRequest`:
    - `password`: max 128 characters.
    - `tokens`: max 2048 characters.
  - Enforced string bounds on audio upload fields: `title` (max 255), `artist_name` (max 255), `album_name` (max 255), `genre` (max 100), `description` (max 5000).
  - Bounded `PlaylistTracksReorder.track_ids` to `max_length=500` to prevent quadratic array processing and memory amplification.

### 3.4. Production Configuration Guardrails (`CWE-1188`)
* **Finding:** Insecure default settings (`SECRET_KEY = "insecure-secret-key-change-in-production"`, `DEBUG = True`, `CORS_ORIGINS = ["*"]`) could silently boot in production environments.
* **Remediation:**
  - Added Pydantic `@model_validator(mode="after")` to `Settings` (`app/core/config.py`).
  - When `APP_ENV == "production"`, the application immediately halts startup with a descriptive `ValueError` if:
    - `SECRET_KEY` is shorter than 32 characters or contains default placeholder substrings.
    - `DEBUG` is set to `True`.
    - `CORS_ORIGINS` contains the wildcard `*`.

### 3.5. Security Headers & Information Reconnaissance Shielding (`CWE-693`, `CWE-200`)
* **Finding:** HTTP responses lacked defensive headers (MIME-sniffing, framing), and interactive API documentation (`/docs`, `/redoc`, `/openapi.json`) remained publicly accessible in all environments.
* **Remediation:**
  - In `app/main.py`, conditionally set `docs_url=None`, `redoc_url=None`, and `openapi_url=None` when `APP_ENV == "production"`.
  - Added defensive security headers middleware enforcing on all responses:
    - `X-Content-Type-Options: nosniff`
    - `X-Frame-Options: DENY`
    - `X-XSS-Protection: 1; mode=block`
    - `Referrer-Policy: strict-origin-when-cross-origin`
    - `Permissions-Policy: camera=(), microphone=(), geolocation=()`
    - `Strict-Transport-Security: max-age=31536000; includeSubDomains` (in production).

### 3.6. Container Least Privilege Hardening (`CWE-250`)
* **Finding:** `backend/Dockerfile` ran application processes as the default `root` user.
* **Remediation:**
  - Created a dedicated non-privileged user `appuser` (UID 1000).
  - Adjusted file ownership `chown -R appuser:appuser /app`.
  - Added `USER appuser` directive before container execution command.

### 3.7. Mobile Client Logging Guard (`CWE-532`)
* **Finding:** Flutter `LoggingInterceptor` printed network request and response payloads to developer system logs in all build modes.
* **Remediation:**
  - Imported `package:flutter/foundation.dart`.
  - Added `if (kReleaseMode) { super.on...; return; }` guards to `onRequest`, `onResponse`, and `onError` in `LoggingInterceptor`.
  - Ensures production release binaries emit zero network diagnostic logs to system consoles.

### 3.8. Data Integrity & Broken Track Handling
* **Finding:** Playlists could reference tracks in a `FAILED` transcode state, creating playback crashes for listeners.
* **Remediation:**
  - Updated `PlaylistService.add_track` to verify track processing status and reject `FAILED` tracks with HTTP 400 `TRACK_FAILED`.

---

## 4. Verification & Testing

### 4.1. Automated Security Test Suite
A dedicated test suite (`backend/tests/test_security.py`) was created and verified:
* `test_security_headers_present`: PASSED (verifies presence of all defensive HTTP headers).
* `test_production_rejects_weak_secret_key`: PASSED (verifies startup failure on weak secret).
* `test_production_rejects_debug_mode`: PASSED (verifies startup failure on active debug flag).
* `test_production_rejects_wildcard_cors`: PASSED (verifies startup failure on wildcard origin).
* `test_login_rejects_pathological_password_length`: PASSED (verifies 422 on oversized password).
* `test_audio_upload_rejects_excessive_metadata_length`: PASSED (verifies 400 INVALID_TRACK_DATA).
* `test_upload_file_bounded_oversized_rejection`: PASSED (verifies immediate stream truncation and error).
* `test_playlist_reorder_rejects_excessive_track_count`: PASSED (verifies 422 on >500 track IDs).
* `test_rate_limiter_enforces_limit_and_returns_429`: PASSED (verifies 429 and Retry-After header).
* `test_tampered_jwt_token_is_rejected`: PASSED (verifies 401 on tampered cryptographic signature).
* `test_playlist_idor_cross_user_isolation`: PASSED (verifies 403/404 on cross-tenant resource tampering).
* `test_cannot_add_failed_track_to_playlist`: PASSED (verifies 400 on adding failed tracks).

### 4.2. Full Test Suite Regression Results
* **Backend:** 86 passed out of 86 tests (`pytest`).
* **Mobile:** 119 passed out of 119 tests (`flutter test`).
* **Mobile Analysis:** 0 issues found (`flutter analyze`).

### 4.3. Dependency Vulnerability Audits
* **Python Backend:** Executed `pip-audit` across the virtual environment:
  - Total packages scanned: 58
  - Known vulnerabilities: 0
* **Flutter Mobile:** Executed `flutter pub outdated`:
  - 0 known security vulnerabilities reported.

---

## 5. Residual Risks & Future Architectural Recommendations

1. **Pre-signed Upload URLs for Object Storage:**
   - *Current State:* File uploads flow through the FastAPI server to MinIO.
   - *Recommendation:* Transitioning to direct client-to-S3/MinIO pre-signed upload URLs in a future release will eliminate proxy server CPU/bandwidth overhead entirely.
2. **Web Application Firewall (WAF):**
   - *Current State:* Rate limiting and header enforcement occur at the application level.
   - *Recommendation:* Complement application-level rate limiting with an edge WAF (e.g. Cloudflare / AWS WAF) for Layer 3/4 DDoS mitigation before traffic reaches container infrastructure.
3. **Database Connection Encryption:**
   - *Current State:* Local Docker setups connect via unencrypted PostgreSQL connections.
   - *Recommendation:* Enforce `sslmode=verify-full` in production deployment manifests with managed database providers (e.g. AWS RDS / GCP Cloud SQL).
