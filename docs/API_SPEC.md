# HUMS — API Specification

**API Version:** 1.0.0  
**Base URL:** `http://localhost:8000` (Local) / `https://api.hums.audio` (Production)  
**API Prefix:** `/api/v1`  
**Content-Type:** `application/json`  

---

## 1. Response & Error Contract

All responses conform to a unified standard structure.

### 1.1 Success Envelope
```json
{
  "success": true,
  "data": { ... },
  "meta": {
    "timestamp": "2026-09-17T16:00:00Z",
    "version": "1.0.0"
  }
}
```

### 1.2 Error Envelope
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE_STRING",
    "message": "Human readable explanation",
    "details": {}
  }
}
```

Standard Error Codes:
* `VALIDATION_ERROR`: Malformed input or schema validation failure (HTTP 422).
* `UNAUTHORIZED`: Missing or invalid authentication token (HTTP 401).
* `FORBIDDEN`: Insufficient permissions (HTTP 403).
* `NOT_FOUND`: Resource could not be located (HTTP 404).
* `SERVICE_UNAVAILABLE`: Upstream dependency failure (e.g., DB down) (HTTP 503).
* `INTERNAL_SERVER_ERROR`: Unhandled server exception (HTTP 500).

---

## 2. Foundation Endpoints

### 2.1 Root Health Check

Returns shallow server liveness check.

* **Method:** `GET`
* **Path:** `/health`
* **Authentication:** None
* **Request:** None
* **Response (200 OK):**
  ```json
  {
    "status": "healthy",
    "app": "Hums",
    "environment": "development"
  }
  ```

---

### 2.2 Deep System Health Check

Returns deep health check validating database connectivity, Redis connection, and service health.

* **Method:** `GET`
* **Path:** `/api/v1/health`
* **Authentication:** None
* **Request:** None
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": {
      "status": "healthy",
      "version": "1.0.0",
      "environment": "development",
      "services": {
        "database": "connected",
        "redis": "connected"
      }
    },
    "meta": {
      "timestamp": "2026-09-17T16:00:00Z",
      "version": "1.0.0"
    }
  }
  ```
* **Response (503 Service Unavailable):**
  ```json
  {
    "success": false,
    "error": {
      "code": "SERVICE_UNAVAILABLE",
      "message": "One or more core services are degraded or unreachable",
      "details": {
        "services": {
          "database": "disconnected",
          "redis": "connected"
        }
      }
    }
  }
  ```

---

## 3. Authentication Endpoints

### 3.1 Register User Account
Registers a new user account with email and password, returning tokens and user details.

* **Method:** `POST`
* **Path:** `/api/v1/auth/register`
* **Authentication:** None
* **Request Body:**
  ```json
  {
    "email": "listener@example.com",
    "password": "SecurePassword123!",
    "full_name": "Jane Doe"
  }
  ```
* **Response (201 Created):**
  ```json
  {
    "success": true,
    "data": {
      "access_token": "eyJhbGciOiJIUzI1NiIs...",
      "refresh_token": "a1b2c3d4e5f6...",
      "token_type": "bearer",
      "expires_in": 1800,
      "user": {
        "id": "123e4567-e89b-12d3-a456-426614174000",
        "email": "listener@example.com",
        "username": "listener",
        "full_name": "Jane Doe",
        "avatar_url": null,
        "is_active": true,
        "is_verified": false,
        "created_at": "2026-09-20T10:00:00Z",
        "updated_at": "2026-09-20T10:00:00Z",
        "last_login_at": null
      }
    },
    "meta": { "timestamp": "2026-09-20T10:00:00Z", "version": "1.0.0" }
  }
  ```
* **Error Responses:**
  * `409 Conflict`: `{"success": false, "error": {"code": "EMAIL_ALREADY_EXISTS", "message": "A user with this email already exists."}}`
  * `422 Unprocessable Entity`: `VALIDATION_ERROR` (e.g., password too short or invalid email)

---

### 3.2 Authenticate / Login
Authenticates an existing user via email and password, issuing access and refresh tokens.

* **Method:** `POST`
* **Path:** `/api/v1/auth/login`
* **Authentication:** None
* **Request Body:**
  ```json
  {
    "email": "listener@example.com",
    "password": "SecurePassword123!"
  }
  ```
* **Response (200 OK):** Same payload as 3.1 `POST /api/v1/auth/register`.
* **Error Responses:**
  * `401 Unauthorized`: `{"success": false, "error": {"code": "INVALID_CREDENTIALS", "message": "Invalid email or password."}}`
  * `403 Forbidden`: `{"success": false, "error": {"code": "USER_INACTIVE", "message": "User account is inactive."}}`

---

### 3.3 Refresh Tokens (Session Rotation)
Rotates refresh token and generates a new access token. Revokes the supplied refresh token to prevent replay attacks.

* **Method:** `POST`
* **Path:** `/api/v1/auth/refresh`
* **Authentication:** None (Refresh token in request body)
* **Request Body:**
  ```json
  {
    "refresh_token": "a1b2c3d4e5f6..."
  }
  ```
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": {
      "access_token": "eyJhbGciOiJIUzI1NiIs...",
      "refresh_token": "new-refresh-token-hex...",
      "token_type": "bearer",
      "expires_in": 1800
    },
    "meta": { "timestamp": "2026-09-20T10:00:00Z", "version": "1.0.0" }
  }
  ```
* **Error Responses:**
  * `401 Unauthorized`: `{"success": false, "error": {"code": "INVALID_REFRESH_TOKEN", "message": "Invalid refresh token."}}`
  * `401 Unauthorized`: `{"success": false, "error": {"code": "REFRESH_TOKEN_EXPIRED", "message": "Refresh token has expired."}}`
  * `401 Unauthorized`: `{"success": false, "error": {"code": "REFRESH_TOKEN_REVOKED", "message": "Refresh token has been revoked."}}`

---

### 3.4 Logout (Revocation)
Explicitly revokes active refresh token and terminates session.

* **Method:** `POST`
* **Path:** `/api/v1/auth/logout`
* **Authentication:** Optional Bearer token or refresh token in body
* **Request Body:**
  ```json
  {
    "refresh_token": "a1b2c3d4e5f6..."
  }
  ```
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": {
      "message": "Successfully logged out."
    },
    "meta": { "timestamp": "2026-09-20T10:00:00Z", "version": "1.0.0" }
  }
  ```

---

### 3.5 Current User Profile
Retrieves the currently authenticated user's profile and account metadata.

* **Method:** `GET`
* **Path:** `/api/v1/auth/me` (alias: `/api/v1/users/me`)
* **Authentication:** `Bearer <access_token>`
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": {
      "id": "123e4567-e89b-12d3-a456-426614174000",
      "email": "listener@example.com",
      "username": "listener",
      "full_name": "Jane Doe",
      "avatar_url": null,
      "is_active": true,
      "is_verified": false,
      "created_at": "2026-09-20T10:00:00Z",
      "updated_at": "2026-09-20T10:00:00Z",
      "last_login_at": "2026-09-20T10:00:00Z"
    },
    "meta": { "timestamp": "2026-09-20T10:00:00Z", "version": "1.0.0" }
  }
  ```
* **Error Responses:**
  * `401 Unauthorized`: `{"success": false, "error": {"code": "UNAUTHORIZED", "message": "Could not validate credentials."}}`

---

### 3.6 Forgot Password (Initiate Reset)
Initiates password reset flow. Emits generic success response regardless of email existence to prevent user enumeration.

* **Method:** `POST`
* **Path:** `/api/v1/auth/forgot-password`
* **Authentication:** None
* **Request Body:**
  ```json
  {
    "email": "listener@example.com"
  }
  ```
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": {
      "message": "If that email is registered, password reset instructions have been sent."
    },
    "meta": { "timestamp": "2026-09-20T10:00:00Z", "version": "1.0.0" }
  }
  ```

---

### 3.7 Reset Password (Execute Reset)
Consumes a single-use reset token to update the user's password and revokes all active refresh sessions.

* **Method:** `POST`
* **Path:** `/api/v1/auth/reset-password`
* **Authentication:** None
* **Request Body:**
  ```json
  {
    "token": "d8f7e6a5b4c3...",
    "new_password": "NewSecurePassword123!"
  }
  ```
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": {
      "message": "Password has been successfully reset. Please log in with your new credentials."
    },
    "meta": { "timestamp": "2026-09-20T10:00:00Z", "version": "1.0.0" }
  }
  ```
* **Error Responses:**
  * `400 Bad Request`: `{"success": false, "error": {"code": "INVALID_RESET_TOKEN", "message": "Invalid or already used password reset token."}}`
  * `400 Bad Request`: `{"success": false, "error": {"code": "EXPIRED_RESET_TOKEN", "message": "Password reset token has expired."}}`

---

## 4. Profile Endpoints

### 4.1 Get Authenticated Profile
Retrieves the profile information for the currently authenticated user.

* **Method:** `GET`
* **Path:** `/api/v1/profile`
* **Authentication:** `Bearer <access_token>`
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": {
      "id": "123e4567-e89b-12d3-a456-426614174000",
      "name": "Ronak Jeengar",
      "email": "listener@example.com",
      "username": "ronak",
      "avatar_url": "http://localhost:9000/hums-audio/avatars/123e4567-e89b-12d3-a456-426614174000/a1b2c3d4.webp",
      "bio": "Audio enthusiast, podcast listener, and music creator.",
      "created_at": "2026-09-20T10:00:00Z",
      "updated_at": "2026-09-20T10:00:00Z"
    },
    "meta": { "timestamp": "2026-09-20T10:00:00Z", "version": "1.0.0" }
  }
  ```
* **Error Responses:**
  * `401 Unauthorized`: `{"success": false, "error": {"code": "UNAUTHORIZED", "message": "Authorization bearer token is missing"}}`

---

### 4.2 Update Profile
Partially updates name, email, or bio for the authenticated user. Only fields provided in the request body are updated.

* **Method:** `PATCH`
* **Path:** `/api/v1/profile`
* **Authentication:** `Bearer <access_token>`
* **Request Body:**
  ```json
  {
    "name": "Ronak Updated",
    "email": "new.email@example.com",
    "bio": "Updated acoustic profile summary"
  }
  ```
* **Response (200 OK):** Returns updated `ProfileResponse` payload.
* **Error Responses:**
  * `400 Bad Request`: `{"success": false, "error": {"code": "INVALID_PROFILE_DATA", "message": "Name must be at least 2 characters long."}}`
  * `409 Conflict`: `{"success": false, "error": {"code": "EMAIL_ALREADY_EXISTS", "message": "A user with this email already exists."}}`
  * `422 Unprocessable Entity`: `VALIDATION_ERROR` (e.g., bio > 500 characters or invalid email format)

---

### 4.3 Upload Avatar
Uploads, optimizes, and replaces the user's avatar image. Previous avatar is safely deleted from object storage upon successful upload.

* **Method:** `POST`
* **Path:** `/api/v1/profile/avatar`
* **Authentication:** `Bearer <access_token>`
* **Content-Type:** `multipart/form-data`
* **Request Body:** Form field `file` with image file data.
* **Restrictions:**
  * Allowed formats: JPEG, PNG, WebP
  * Maximum size: 5 MB (configurable via `MAX_AVATAR_SIZE_MB`)
  * Minimum dimensions: 32x32 pixels; Maximum dimensions: 4096x4096 pixels
  * Processed output: Resized to max 1024x1024 keeping aspect ratio, metadata stripped, WebP format
* **Response (200 OK):** Returns updated `ProfileResponse` with new `avatar_url`.
* **Error Responses:**
  * `400 Bad Request`: `{"success": false, "error": {"code": "UNSUPPORTED_IMAGE_TYPE", "message": "Unsupported image type. Allowed formats: JPEG, PNG, WebP."}}`
  * `400 Bad Request`: `{"success": false, "error": {"code": "IMAGE_TOO_LARGE", "message": "Avatar image exceeds the 5MB size limit."}}`
  * `400 Bad Request`: `{"success": false, "error": {"code": "INVALID_IMAGE", "message": "Invalid or corrupted image file."}}`

---

### 4.4 Remove Avatar
Deletes the user's avatar image from object storage and sets `avatar_url` to null. Idempotent when no avatar exists.

* **Method:** `DELETE`
* **Path:** `/api/v1/profile/avatar`
* **Authentication:** `Bearer <access_token>`
* **Response (200 OK):** Returns updated `ProfileResponse` with `"avatar_url": null`.
* **Error Responses:**
  * `401 Unauthorized`: `{"success": false, "error": {"code": "UNAUTHORIZED", "message": "Authorization bearer token is missing"}}`

---

## 5. Audio Endpoints

### 5.1 Upload Audio Track
Uploads an audio file with track metadata, stores it in S3-compatible storage, creates database records for the track and audio file, and enqueues an asynchronous processing job.

* **Method:** `POST`
* **Path:** `/api/v1/audio/upload`
* **Authentication:** `Bearer <access_token>`
* **Content-Type:** `multipart/form-data`
* **Request Form Fields:**
  * `file`: (File, required) Audio binary data. Allowed formats: MP3, WAV, FLAC, M4A, AAC, OGG. Max size: 100MB (`MAX_AUDIO_SIZE_MB`).
  * `title`: (string, required) Track title (1–255 characters).
  * `artist_name`: (string, optional) Artist or band name.
  * `album_name`: (string, optional) Album or EP name.
  * `genre`: (string, optional) Genre classification.
  * `description`: (string, optional) Track description, show notes, or lyrics.
* **Response (201 Created):**
  ```json
  {
    "success": true,
    "data": {
      "id": "7b0a9d94-d456-425b-b9f4-18889bf656a8",
      "owner_id": "123e4567-e89b-12d3-a456-426614174000",
      "title": "Midnight Hums",
      "description": "A relaxing midnight acoustic session.",
      "artist_name": "Acoustic Wonder",
      "album_name": "Night Sessions",
      "genre": "Ambient",
      "duration_seconds": null,
      "status": "UPLOADED",
      "created_at": "2026-09-20T15:00:00Z",
      "updated_at": "2026-09-20T15:00:00Z",
      "audio_files": [
        {
          "id": "e4b2d113-5678-4321-abcd-ef0123456789",
          "track_id": "7b0a9d94-d456-425b-b9f4-18889bf656a8",
          "object_key": "audio/original/123e4567-e89b-12d3-a456-426614174000/7b0a9d94-d456-425b-b9f4-18889bf656a8/e4b2d113-5678-4321-abcd-ef0123456789.mp3",
          "storage_provider": "s3",
          "original_filename": "midnight.mp3",
          "mime_type": "audio/mpeg",
          "file_size_bytes": 5242880,
          "created_at": "2026-09-20T15:00:00Z",
          "updated_at": "2026-09-20T15:00:00Z"
        }
      ],
      "processing_jobs": [
        {
          "id": "f5c3e224-6789-5432-bcde-fa1234567890",
          "track_id": "7b0a9d94-d456-425b-b9f4-18889bf656a8",
          "job_type": "AUDIO_TRANSCODE",
          "status": "PENDING",
          "attempts": 0,
          "error_message": null,
          "created_at": "2026-09-20T15:00:00Z",
          "updated_at": "2026-09-20T15:00:00Z"
        }
      ]
    },
    "meta": { "timestamp": "2026-09-20T15:00:00Z", "version": "1.0.0" }
  }
  ```
* **Error Responses:**
  * `400 Bad Request`: `{"success": false, "error": {"code": "INVALID_AUDIO_FORMAT", "message": "Uploaded file is not a valid audio file or format is unsupported."}}`
  * `400 Bad Request`: `{"success": false, "error": {"code": "AUDIO_TOO_LARGE", "message": "Audio file exceeds maximum allowed size of 100MB."}}`
  * `400 Bad Request`: `{"success": false, "error": {"code": "INVALID_AUDIO_FILE", "message": "Audio file is too small or empty."}}`
  * `400 Bad Request`: `{"success": false, "error": {"code": "INVALID_TRACK_DATA", "message": "Track title is required."}}`
  * `401 Unauthorized`: `{"success": false, "error": {"code": "UNAUTHORIZED", "message": "Authorization bearer token is missing"}}`

---

### 5.2 List User Tracks
Returns a paginated list of audio tracks uploaded by the currently authenticated user.

* **Method:** `GET`
* **Path:** `/api/v1/audio/tracks`
* **Authentication:** `Bearer <access_token>`
* **Query Parameters:**
  * `skip`: (integer, optional, default: 0) Number of records to skip.
  * `limit`: (integer, optional, default: 50, max: 100) Number of records to return.
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": [
      {
        "id": "7b0a9d94-d456-425b-b9f4-18889bf656a8",
        "owner_id": "123e4567-e89b-12d3-a456-426614174000",
        "title": "Midnight Hums",
        "description": "A relaxing midnight acoustic session.",
        "artist_name": "Acoustic Wonder",
        "album_name": "Night Sessions",
        "genre": "Ambient",
        "duration_seconds": null,
        "status": "UPLOADED",
        "created_at": "2026-09-20T15:00:00Z",
        "updated_at": "2026-09-20T15:00:00Z",
        "audio_files": [...],
        "processing_jobs": [...]
      }
    ],
    "meta": { "timestamp": "2026-09-20T15:00:00Z", "version": "1.0.0" }
  }
  ```

---

### 5.3 Get Track Details
Retrieves track metadata, audio files, and processing jobs for a specific track owned by the user.

* **Method:** `GET`
* **Path:** `/api/v1/audio/tracks/{track_id}`
* **Authentication:** `Bearer <access_token>`
* **Response (200 OK):** Returns single `TrackResponse` payload.
* **Error Responses:**
  * `404 Not Found`: `{"success": false, "error": {"code": "NOT_FOUND", "message": "Track not found"}}`

---

### 5.4 Get Track Status
Retrieves lightweight upload and processing status for a specific track.

* **Method:** `GET`
* **Path:** `/api/v1/audio/tracks/{track_id}/status`
* **Authentication:** `Bearer <access_token>`
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": {
      "track_id": "7b0a9d94-d456-425b-b9f4-18889bf656a8",
      "title": "Midnight Hums",
      "status": "READY",
      "duration_seconds": 210,
      "waveform_key": "audio/waveforms/7b0a9d94-d456-425b-b9f4-18889bf656a8.json",
      "processing_job_id": "f5c3e224-6789-5432-bcde-fa1234567890",
      "processing_status": "COMPLETED",
      "error_message": null,
      "updated_at": "2026-09-20T15:00:00Z"
    },
    "meta": { "timestamp": "2026-09-20T15:00:00Z", "version": "1.0.0" }
  }
  ```

---

### 5.5 Get Processing Job Status
Retrieves processing job status, attempt count, and diagnostic error details for an asynchronous media job.

* **Method:** `GET`
* **Path:** `/api/v1/audio/jobs/{job_id}`
* **Authentication:** `Bearer <access_token>`
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": {
      "id": "f5c3e224-6789-5432-bcde-fa1234567890",
      "track_id": "7b0a9d94-d456-425b-b9f4-18889bf656a8",
      "job_type": "AUDIO_TRANSCODE",
      "status": "COMPLETED",
      "attempts": 1,
      "error_message": null,
      "created_at": "2026-09-20T15:00:00Z",
      "updated_at": "2026-09-20T15:00:00Z"
    },
    "meta": { "timestamp": "2026-09-20T15:00:00Z", "version": "1.0.0" }
  }
  ```
* **Error Responses:**
  * `404 Not Found`: `{"success": false, "error": {"code": "NOT_FOUND", "message": "Processing job not found"}}`

---

### 5.6 Get Track Waveform
Retrieves the 200 normalized amplitude points for a processed track.

* **Method:** `GET`
* **Path:** `/api/v1/audio/tracks/{track_id}/waveform`
* **Authentication:** `Bearer <access_token>`
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": {
      "track_id": "7b0a9d94-d456-425b-b9f4-18889bf656a8",
      "samples": [
        0.0,
        0.1452,
        0.4589,
        0.8921,
        1.0,
        0.7234,
        0.3121
      ]
    },
    "meta": { "timestamp": "2026-09-20T15:00:00Z", "version": "1.0.0" }
  }
  ```
* **Error Responses:**
  * `404 Not Found`: `{"success": false, "error": {"code": "NOT_FOUND", "message": "Track not found"}}`

---

### 5.7 Get Track Playback Source
Retrieves playback metadata and secure streaming URL for a `READY` track. Returns the highest-quality available rendition and amplitude waveform samples.

* **Method:** `GET`
* **Path:** `/api/v1/audio/tracks/{track_id}/playback`
* **Authentication:** `Bearer <access_token>`
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": {
      "track_id": "7b0a9d94-d456-425b-b9f4-18889bf656a8",
      "title": "Midnight Hums",
      "artist_name": "Luna Wave",
      "album_name": "Echoes",
      "genre": "Acoustic",
      "duration_seconds": 210,
      "status": "READY",
      "audio": {
        "url": "https://s3.example.com/audio/processed/7b0a9d94-d456-425b-b9f4-18889bf656a8/rendition-192.m4a",
        "format": "m4a",
        "codec": "aac",
        "bitrate_kbps": 192,
        "duration_seconds": 210,
        "file_size_bytes": 5040000
      },
      "waveform_samples": [
        0.0,
        0.1452,
        0.4589,
        0.8921,
        1.0,
        0.7234,
        0.3121
      ]
    },
    "meta": { "timestamp": "2026-09-20T15:00:00Z", "version": "1.0.0" }
  }
  ```
* **Error Responses:**
  * `401 Unauthorized`: `{"success": false, "error": {"code": "UNAUTHORIZED", "message": "Could not validate credentials"}}`
  * `404 Not Found`: `{"success": false, "error": {"code": "NOT_FOUND", "message": "Track not found"}}`
  * `409 Conflict`: `{"success": false, "error": {"code": "TRACK_NOT_READY", "message": "Track is not ready for playback (current status: PROCESSING)"}}`

---

### 5.8 Authorize & Download Audio Track
Authorizes an authenticated user to download an eligible audio track for offline playback. Returns a short-lived presigned URL (15 minutes), file metadata, bitrate, and waveform samples.

* **Method:** `GET`
* **Path:** `/api/v1/tracks/{track_id}/download` (Alias: `/api/v1/audio/tracks/{track_id}/download`)
* **Authentication:** `Bearer <access_token>`
* **Rate Limit:** 30 requests / 60 seconds per IP/user
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": {
      "track_id": "7b0a9d94-d456-425b-b9f4-18889bf656a8",
      "title": "Midnight Hums",
      "artist_name": "Ronak",
      "album_name": "Acoustic Nights",
      "genre": "Acoustic",
      "duration_seconds": 210,
      "status": "READY",
      "format": "m4a",
      "codec": "aac",
      "bitrate_kbps": 256,
      "file_size_bytes": 6710886,
      "download_url": "https://storage.hums.app/audio/processed/7b0a9d94.../audio.m4a?X-Amz-Signature=...",
      "expires_at": "2026-09-25T15:45:00Z",
      "waveform_samples": [0.1, 0.45, 0.89, 1.0, 0.72]
    },
    "meta": { "timestamp": "2026-09-25T15:30:00Z", "version": "1.0.0" }
  }
  ```
* **Error Responses:**
  * `401 Unauthorized`: `{"success": false, "error": {"code": "UNAUTHORIZED", "message": "Could not validate credentials"}}`
  * `403 Forbidden`: `{"success": false, "error": {"code": "FORBIDDEN", "message": "You do not have permission to download this track"}}`
  * `404 Not Found`: `{"success": false, "error": {"code": "NOT_FOUND", "message": "Track not found"}}`
  * `409 Conflict`: `{"success": false, "error": {"code": "TRACK_NOT_READY", "message": "Track is not ready for download (current status: PROCESSING)"}}`
  * `429 Too Many Requests`: `{"success": false, "error": {"code": "RATE_LIMIT_EXCEEDED", "message": "Rate limit exceeded. Try again in 30 seconds."}}`

---

## 6. Playlist Endpoints

### 6.1 Create Playlist
Creates a user-owned playlist with name and optional description.

* **Method:** `POST`
* **Path:** `/api/v1/playlists`
* **Authentication:** `Bearer <access_token>`
* **Request Body:**
  ```json
  {
    "name": "Midnight Chill",
    "description": "Late night acoustics and beats",
    "is_public": false
  }
  ```
* **Response (201 Created):**
  ```json
  {
    "success": true,
    "data": {
      "id": "2d1f7c32-b7e1-4321-9e23-28dbca579fa1",
      "owner_id": "8f3b2e10-a1b2-4c3d-8e4f-5a6b7c8d9e0f",
      "name": "Midnight Chill",
      "description": "Late night acoustics and beats",
      "cover_image_key": null,
      "cover_image_url": null,
      "is_public": false,
      "track_count": 0,
      "duration_seconds": 0,
      "created_at": "2026-09-21T12:00:00Z",
      "updated_at": "2026-09-21T12:00:00Z"
    },
    "meta": { "timestamp": "2026-09-21T12:00:00Z", "version": "1.0.0" }
  }
  ```
* **Error Responses:**
  * `401 Unauthorized`: Missing or invalid token.
  * `422 Unprocessable Content`: Empty or invalid name.

---

### 6.2 List User Playlists
Returns a paginated list of playlists owned by the authenticated user.

* **Method:** `GET`
* **Path:** `/api/v1/playlists?skip=0&limit=50`
* **Authentication:** `Bearer <access_token>`
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": [
      {
        "id": "2d1f7c32-b7e1-4321-9e23-28dbca579fa1",
        "owner_id": "8f3b2e10-a1b2-4c3d-8e4f-5a6b7c8d9e0f",
        "name": "Midnight Chill",
        "description": "Late night acoustics and beats",
        "cover_image_key": "playlists/covers/2d1f7c32-b7e1-4321-9e23-28dbca579fa1/cover.webp",
        "cover_image_url": "https://s3.example.com/playlists/covers/2d1f7c32-b7e1-4321-9e23-28dbca579fa1/cover.webp",
        "is_public": false,
        "track_count": 3,
        "duration_seconds": 630,
        "created_at": "2026-09-21T12:00:00Z",
        "updated_at": "2026-09-21T12:30:00Z"
      }
    ],
    "meta": { "timestamp": "2026-09-21T12:00:00Z", "version": "1.0.0" }
  }
  ```

---

### 6.3 Get Playlist Details
Returns complete playlist details including all ordered track items.

* **Method:** `GET`
* **Path:** `/api/v1/playlists/{playlist_id}`
* **Authentication:** `Bearer <access_token>`
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": {
      "id": "2d1f7c32-b7e1-4321-9e23-28dbca579fa1",
      "owner_id": "8f3b2e10-a1b2-4c3d-8e4f-5a6b7c8d9e0f",
      "name": "Midnight Chill",
      "description": "Late night acoustics and beats",
      "cover_image_key": null,
      "cover_image_url": null,
      "is_public": false,
      "track_count": 1,
      "duration_seconds": 210,
      "created_at": "2026-09-21T12:00:00Z",
      "updated_at": "2026-09-21T12:00:00Z",
      "tracks": [
        {
          "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
          "track_id": "7b0a9d94-d456-425b-b9f4-18889bf656a8",
          "position": 0,
          "added_at": "2026-09-21T12:05:00Z",
          "title": "Midnight Hums",
          "artist_name": "Luna Wave",
          "album_name": "Echoes",
          "duration_seconds": 210,
          "waveform_key": "audio/waveforms/7b0a9d94-d456-425b-b9f4-18889bf656a8.json",
          "status": "READY"
        }
      ]
    },
    "meta": { "timestamp": "2026-09-21T12:00:00Z", "version": "1.0.0" }
  }
  ```
* **Error Responses:**
  * `404 Not Found`: Playlist does not exist or belongs to another user.

---

### 6.4 Update Playlist Metadata
Updates name, description, or visibility for an owned playlist.

* **Method:** `PATCH`
* **Path:** `/api/v1/playlists/{playlist_id}`
* **Authentication:** `Bearer <access_token>`
* **Request Body:**
  ```json
  {
    "name": "Updated Title",
    "description": "Updated description",
    "is_public": true
  }
  ```
* **Response (200 OK):** Updated `PlaylistResponse`.

---

### 6.5 Delete Playlist
Permanently deletes a playlist, its track memberships, and its cover artwork.

* **Method:** `DELETE`
* **Path:** `/api/v1/playlists/{playlist_id}`
* **Authentication:** `Bearer <access_token>`
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": { "message": "Playlist deleted successfully" },
    "meta": { "timestamp": "2026-09-21T12:00:00Z", "version": "1.0.0" }
  }
  ```

---

### 6.6 Upload Playlist Cover Artwork
Uploads and processes artwork image (JPEG, PNG, WebP up to 5MB) for a playlist, converted to WebP (800x800 max).

* **Method:** `POST`
* **Path:** `/api/v1/playlists/{playlist_id}/cover`
* **Authentication:** `Bearer <access_token>`
* **Content-Type:** `multipart/form-data`
* **Request Body:** `file` (binary)
* **Response (200 OK):** Updated `PlaylistResponse` with `cover_image_url`.

---

### 6.7 Remove Playlist Cover Artwork
Removes the cover artwork from a playlist and deletes the underlying S3 object.

* **Method:** `DELETE`
* **Path:** `/api/v1/playlists/{playlist_id}/cover`
* **Authentication:** `Bearer <access_token>`
* **Response (200 OK):** Updated `PlaylistResponse` with null `cover_image_key` and `cover_image_url`.

---

### 6.8 Add Track to Playlist
Appends a track to the end of the playlist.

* **Method:** `POST`
* **Path:** `/api/v1/playlists/{playlist_id}/tracks`
* **Authentication:** `Bearer <access_token>`
* **Request Body:**
  ```json
  {
    "track_id": "7b0a9d94-d456-425b-b9f4-18889bf656a8"
  }
  ```
* **Response (200 OK):** Updated `PlaylistDetailResponse`.
* **Error Responses:**
  * `400 Bad Request`: Track is already in this playlist.
  * `404 Not Found`: Track or playlist not found.

---

### 6.9 Remove Track from Playlist
Removes a track membership and normalizes remaining positions without deleting the track itself.

* **Method:** `DELETE`
* **Path:** `/api/v1/playlists/{playlist_id}/tracks/{track_id}`
* **Authentication:** `Bearer <access_token>`
* **Response (200 OK):** Updated `PlaylistDetailResponse`.
* **Error Responses:**
  * `404 Not Found`: Track not found in this playlist.

---

### 6.10 Reorder Tracks in Playlist
Atomically updates track positions based on the submitted list of track IDs.

* **Method:** `PATCH`
* **Path:** `/api/v1/playlists/{playlist_id}/tracks/reorder`
* **Authentication:** `Bearer <access_token>`
* **Request Body:**
  ```json
  {
    "track_ids": [
      "7b0a9d94-d456-425b-b9f4-18889bf656a8",
      "e3a1b2c4-d5e6-7890-abcd-1234567890ab"
    ]
  }
  ```
* **Response (200 OK):** Updated `PlaylistDetailResponse` with tracks ordered by new positions.
* **Error Responses:**
  * `400 Bad Request`: Submitted track IDs do not match the current playlist track membership.

---

## 7. Recommendation Endpoints

### 7.1 Get Personalized Recommendations
Retrieves categorized recommendation sections (`for-you`, `genre`, `trending`, `discover`) tailored to the authenticated user. Results are served from the Redis cache (TTL 300s) or dynamically computed and persisted.

* **Method:** `GET`
* **Path:** `/api/v1/recommendations`
* **Authentication:** `Bearer <access_token>`
* **Query Parameters:**
  * `limit` (optional integer, default `10`, min `1`, max `50`): Maximum recommendations per section.
  * `section` (optional string): Filter for a specific section (`for-you`, `genre`, `trending`, `discover`).
  * `refresh` (optional boolean, default `false`): When `true`, bypasses the cached recommendation set and computes fresh recommendations immediately.
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": {
      "sections": [
        {
          "id": "for-you",
          "title": "Personalized For You",
          "description": "Curated tracks based on your listening patterns and playlists",
          "items": [
            {
              "id": "7b0a9d94-d456-425b-b9f4-18889bf656a8",
              "title": "Midnight Resonance",
              "artist_name": "Acoustic Horizon",
              "album_name": "Warm Tides",
              "genre": "Ambient",
              "duration_seconds": 240,
              "artwork_url": "https://cdn.hums.audio/art/7b0a9d94.jpg",
              "status": "READY",
              "waveform_key": "waveforms/7b0a9d94.json"
            }
          ]
        },
        {
          "id": "genre",
          "title": "More Ambient For You",
          "description": "Deep cuts from your most listened genre",
          "items": [ ... ]
        },
        {
          "id": "trending",
          "title": "Trending on Hums",
          "description": "Popular tracks across the platform",
          "items": [ ... ]
        },
        {
          "id": "discover",
          "title": "Discover New Sounds",
          "description": "Fresh releases and artists to expand your taste",
          "items": [ ... ]
        }
      ]
    },
    "meta": {
      "timestamp": "2026-09-22T21:00:00Z",
      "version": "1.0.0"
    }
  }
  ```
* **Error Responses:**
  * `401 Unauthorized`: Missing or invalid JWT access token.
  * `422 Validation Error`: Invalid query parameters (e.g., limit > 50).

---

### 7.2 Trigger Background Recommendation Refresh
Enqueues a background Celery worker task to recompute recommendations for the user and invalidate stale caches. Features a 30-second debounce window to prevent denial-of-service or cache-busting storms.

* **Method:** `POST`
* **Path:** `/api/v1/recommendations/refresh`
* **Authentication:** `Bearer <access_token>`
* **Request Body:** None
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": {
      "status": "queued",
      "message": "Recommendation refresh queued"
    },
    "meta": {
      "timestamp": "2026-09-22T21:00:00Z",
      "version": "1.0.0"
    }
  }
  ```
* **Error Responses:**
  * `401 Unauthorized`: Missing or invalid JWT access token.

---

## 8. Push Notifications & Inbox Endpoints

All notification endpoints require authentication via standard JWT Bearer header: `Authorization: Bearer <access_token>`.

### 8.1 Register / Update Device Token
Registers a new device push token or updates an existing token registration.

* **Method:** `POST`
* **Path:** `/api/v1/notifications/devices`
* **Authentication:** `Bearer <access_token>`
* **Request Body:**
  ```json
  {
    "token": "dGVzdF90b2tlbl8xMjM0NQ==",
    "platform": "ANDROID",
    "device_name": "Pixel 8 Pro",
    "app_version": "1.0.0"
  }
  ```
* **Response (201 Created):**
  ```json
  {
    "success": true,
    "data": {
      "id": "e8a958b1-4f10-4bf2-a39c-bc09a478b871",
      "device_token": "dGVzdF90b2tlbl8xMjM0NQ==",
      "platform": "ANDROID",
      "device_name": "Pixel 8 Pro",
      "app_version": "1.0.0",
      "is_active": true,
      "last_seen_at": "2026-09-23T16:00:00Z",
      "created_at": "2026-09-23T16:00:00Z"
    },
    "meta": { "timestamp": "2026-09-23T16:00:00Z", "version": "1.0.0" }
  }
  ```

---

### 8.2 Deactivate Device by ID
Deactivates a specific device owned by the authenticated user.

* **Method:** `DELETE`
* **Path:** `/api/v1/notifications/devices/{device_id}`
* **Authentication:** `Bearer <access_token>`
* **Response (204 No Content)**

---

### 8.3 Deactivate Device by Token
Deactivates a device registration by push token (e.g. upon user logout).

* **Method:** `DELETE`
* **Path:** `/api/v1/notifications/devices?token={token}`
* **Authentication:** `Bearer <access_token>`
* **Response (204 No Content)**

---

### 8.4 Get Notification Preferences
Retrieves user category preferences for push notifications.

* **Method:** `GET`
* **Path:** `/api/v1/notifications/preferences`
* **Authentication:** `Bearer <access_token>`
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": {
      "push_enabled": true,
      "new_releases_enabled": true,
      "playlist_updates_enabled": true,
      "recommendations_enabled": true,
      "processing_updates_enabled": true
    },
    "meta": { "timestamp": "2026-09-23T16:00:00Z", "version": "1.0.0" }
  }
  ```

---

### 8.5 Update Notification Preferences
Updates user category preferences and global push toggle.

* **Method:** `PUT`
* **Path:** `/api/v1/notifications/preferences`
* **Authentication:** `Bearer <access_token>`
* **Request Body:**
  ```json
  {
    "new_releases_enabled": false,
    "processing_updates_enabled": true
  }
  ```
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": {
      "push_enabled": true,
      "new_releases_enabled": false,
      "playlist_updates_enabled": true,
      "recommendations_enabled": true,
      "processing_updates_enabled": true
    },
    "meta": { "timestamp": "2026-09-23T16:00:00Z", "version": "1.0.0" }
  }
  ```

---

### 8.6 List Notifications
Returns paginated in-app notifications for the user.

* **Method:** `GET`
* **Path:** `/api/v1/notifications?skip=0&limit=50&is_read=false`
* **Authentication:** `Bearer <access_token>`
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": {
      "items": [
        {
          "id": "7f1c1a93-8bc4-47b2-bf30-5807490b4e2f",
          "type": "UPLOAD_COMPLETE",
          "title": "Track Ready",
          "body": "\"Midnight Echoes\" has finished processing and is ready to stream!",
          "data": {
            "type": "track",
            "track_id": "9a0a1f0a-c956-42d4-bb06-b33df01a1c3d",
            "screen": "track_detail"
          },
          "is_read": false,
          "read_at": null,
          "created_at": "2026-09-23T16:10:00Z"
        }
      ],
      "total": 1,
      "skip": 0,
      "limit": 50
    },
    "meta": { "timestamp": "2026-09-23T16:10:00Z", "version": "1.0.0" }
  }
  ```

---

### 8.7 Get Unread Notification Count
Returns the fast count of unread notifications for badge indicators.

* **Method:** `GET`
* **Path:** `/api/v1/notifications/unread-count`
* **Authentication:** `Bearer <access_token>`
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": {
      "unread_count": 1
    },
    "meta": { "timestamp": "2026-09-23T16:10:00Z", "version": "1.0.0" }
  }
  ```

---

### 8.8 Mark Notification as Read
Marks a single notification as read.

* **Method:** `PATCH`
* **Path:** `/api/v1/notifications/{notification_id}/read`
* **Authentication:** `Bearer <access_token>`
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": {
      "id": "7f1c1a93-8bc4-47b2-bf30-5807490b4e2f",
      "type": "UPLOAD_COMPLETE",
      "title": "Track Ready",
      "body": "\"Midnight Echoes\" has finished processing and is ready to stream!",
      "data": { "track_id": "9a0a1f0a-c956-42d4-bb06-b33df01a1c3d" },
      "is_read": true,
      "read_at": "2026-09-23T16:12:00Z",
      "created_at": "2026-09-23T16:10:00Z"
    },
    "meta": { "timestamp": "2026-09-23T16:12:00Z", "version": "1.0.0" }
  }
  ```

---

### 8.9 Mark All Notifications as Read
Marks all unread notifications for the user as read in bulk.

* **Method:** `POST`
* **Path:** `/api/v1/notifications/read-all`
* **Authentication:** `Bearer <access_token>`
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": {
      "marked_count": 5
    },
    "meta": { "timestamp": "2026-09-23T16:12:00Z", "version": "1.0.0" }
  }
  ```

---

## 9. Catalog Search Endpoints

### 9.1 Unified Catalog Search
Executes backend-driven full-text, substring, and trigram-ranked relevance search across Tracks, Artists/Creators, and Playlists with privacy isolation.

* **Method:** `GET`
* **Path:** `/api/v1/search`
* **Authentication:** Optional (`Bearer <access_token>` to view personal private playlists)
* **Query Parameters:**
  * `q` (string, optional, default: `""`): Search query string. Gracefully returns empty results for empty or whitespace-only queries.
  * `type` (string, optional, default: `"all"`): Filter by entity type. Allowed: `all`, `tracks`, `artists`, `playlists`.
  * `limit` (integer, optional, default: `20`, min: `1`, max: `50`): Maximum results per entity category.
  * `skip` (integer, optional, default: `0`, min: `0`): Pagination offset.
* **Privacy & Access Control:**
  * **Tracks:** Only tracks with `status == 'READY'` are returned. Unready, pending, processing, or failed tracks are strictly excluded.
  * **Playlists:** Only public playlists (`is_public == true`) are returned to guests. Authenticated users also see their own private playlists (`owner_id == current_user.id`).
  * **Artists:** Returns active creator users and distinct track artists with aggregated ready track counts.
* **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": {
      "query": "Arijit",
      "type": "all",
      "total_tracks": 14,
      "total_artists": 2,
      "total_playlists": 3,
      "tracks": [
        {
          "id": "7f1c1a93-8bc4-47b2-bf30-5807490b4e2f",
          "owner_id": "4e991873-f91e-493b-900c-93dcd6d518b3",
          "title": "Kesariya Tera Ishq Hai Piya",
          "description": "Romantic soundtrack",
          "artist_name": "Arijit Singh",
          "album_name": "Brahmastra",
          "genre": "Romantic",
          "duration_seconds": 268,
          "waveform_key": "waveforms/kesariya.json",
          "status": "READY",
          "created_at": "2026-09-20T12:00:00Z",
          "updated_at": "2026-09-20T12:05:00Z"
        }
      ],
      "artists": [
        {
          "id": "4e991873-f91e-493b-900c-93dcd6d518b3",
          "name": "Arijit Singh",
          "username": "arijit_singh",
          "avatar_url": "https://cdn.hums.audio/avatars/arijit.jpg",
          "bio": "Indian playback singer and music composer",
          "track_count": 14
        }
      ],
      "playlists": [
        {
          "id": "9a0a1f0a-c956-42d4-bb06-b33df01a1c3d",
          "owner_id": "4e991873-f91e-493b-900c-93dcd6d518b3",
          "name": "Arijit Singh Essentials",
          "description": "Curated collection of acoustic hits",
          "cover_image_key": "covers/arijit_essentials.jpg",
          "cover_image_url": "https://cdn.hums.audio/covers/arijit_essentials.jpg",
          "is_public": true,
          "track_count": 14,
          "created_at": "2026-09-21T10:00:00Z",
          "updated_at": "2026-09-21T10:30:00Z"
        }
      ]
    },
    "meta": {
      "timestamp": "2026-09-24T15:20:00Z",
      "version": "1.0.0"
    }
  }
  ```







