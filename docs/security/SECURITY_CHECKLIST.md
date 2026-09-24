# Hums — Production Security Verification Checklist

This checklist serves as the mandatory operational and deployment security verification standard for the **Hums** audio streaming platform prior to staging and production promotions.

---

## 1. Authentication & Session Management

- [x] **Cryptographic Secret Key:** `SECRET_KEY` configured via secure environment variable with at least 32 high-entropy characters; startup rejected in production if default/short string is detected.
- [x] **Password Storage:** Passwords hashed with industry-standard algorithm (Bcrypt/Argon2 with high work factor).
- [x] **Password Input Bounded:** `password` length constrained to 128 characters to prevent hashing CPU starvation DoS.
- [x] **Rate Limiting on Authentication:**
  - [x] `/api/v1/auth/login`: Limited to 15 req/min.
  - [x] `/api/v1/auth/register`: Limited to 10 req/min.
  - [x] `/api/v1/auth/forgot-password`: Limited to 5 req/min.
  - [x] `/api/v1/auth/reset-password`: Limited to 10 req/min.
  - [x] `/api/v1/auth/refresh`: Limited to 30 req/min.
- [x] **Retry-After Header:** Returns RFC 6585-compliant `Retry-After: {seconds}` header when rate limits are exceeded.
- [x] **User Enumeration Prevention:** Password reset requests return generic confirmation messages regardless of whether the email exists.
- [x] **Secure Token Revocation:** Single-use password reset tokens invalidated upon consumption; refresh tokens rotated on refresh and revoked on logout.

---

## 2. Authorization & Tenant Isolation (IDOR Prevention)

- [x] **Playlist Ownership Enforcement:** Non-owners cannot update, delete, or add/remove tracks from private playlists belonging to other users.
- [x] **Track Ownership Verification:** Track deletion and modifications verified against `current_user.id == track.owner_id`.
- [x] **Token Verification:** Tampered or forged JWT signatures rejected with `401 Unauthorized`.
- [x] **State Integrity:** Failed or corrupt audio tracks cannot be inserted into user playlists.

---

## 3. Input Validation & Data Bounds

- [x] **Strict Schema Validation:** All request payloads validated using Pydantic v2 schemas.
- [x] **Audio Metadata Bounds:** `title` (<=255 chars), `artist_name` (<=255 chars), `album_name` (<=255 chars), `genre` (<=100 chars), `description` (<=5000 chars) enforced before database persistence.
- [x] **Reorder Bounds:** `PlaylistTracksReorder.track_ids` bounded to maximum 500 items to prevent database lock amplification.
- [x] **Unprocessable Content Handling:** Returns standard JSON `ApiResponse` format on validation errors with field-level details.

---

## 4. File Upload & Object Storage Security

- [x] **Bounded Streaming:** Uploads read in 64KB bounded chunks via `read_upload_file_bounded`; connection aborted immediately if file exceeds limit:
  - Audio files: 100 MB max.
  - Image files (covers & avatars): 10 MB max.
- [x] **MIME-Type & Magic Byte Validation:** File signatures validated against permitted MIME types (e.g. `audio/mpeg`, `audio/wav`, `audio/flac`, `image/jpeg`, `image/png`).
- [x] **Image Decoding Verification:** Pillow image parsing verifies image file structure; decompression bombs prevented by size and dimension limits.
- [x] **Path Traversal Protection:** User-supplied filenames discarded; storage keys constructed with random UUIDs.

---

## 5. Network & Infrastructure Security

- [x] **Defensive Security Headers:**
  - `X-Content-Type-Options: nosniff`
  - `X-Frame-Options: DENY`
  - `X-XSS-Protection: 1; mode=block`
  - `Referrer-Policy: strict-origin-when-cross-origin`
  - `Permissions-Policy: camera=(), microphone=(), geolocation=()`
  - `Strict-Transport-Security: max-age=31536000; includeSubDomains` (production)
- [x] **Production API Shielding:** `/docs`, `/redoc`, and `/openapi.json` automatically disabled when `APP_ENV == "production"`.
- [x] **CORS Origin Whitelisting:** Explicit origins required; wildcard `*` rejected during startup in production.
- [x] **Container Least Privilege:** Backend Docker container executes under unprivileged `appuser` (UID 1000).
- [x] **Zero Vulnerabilities in Dependencies:** `pip-audit` verifies 0 known vulnerabilities in installed Python packages.

---

## 6. Mobile Application Security

- [x] **Secure Token Storage:** JWT access and refresh tokens stored strictly in `FlutterSecureStorage` (iOS Keychain / Android EncryptedSharedPreferences).
- [x] **Production Log Suppression:** Verbose HTTP logging interceptor disabled in `kReleaseMode` builds to prevent credential leaks to Android Logcat or iOS syslog.
- [x] **Automatic Session Recovery:** Token refresh queued atomically without concurrent refresh storms or infinite retry loops.
