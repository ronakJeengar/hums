# Lyrics API Specification

Base Path: `/api/v1/tracks/{track_id}/lyrics` (Alias: `/api/v1/audio/tracks/{track_id}/lyrics`)

---

### 1. Get Track Lyrics

Retrieves the authoritative lyrics or transcript for the specified audio track.

* **Method**: `GET`
* **Path**: `/api/v1/tracks/{track_id}/lyrics`
* **Authentication**: Optional (publicly viewable, cached in Redis with 1-hour TTL)

#### Responses

**200 OK (Completed Synchronized Lyrics)**
```json
{
  "success": true,
  "data": {
    "id": "7f8c0571-0857-41fe-8b17-062e08c69786",
    "track_id": "c8135d7d-b7ae-44cb-905a-da83e5a0d45a",
    "status": "COMPLETED",
    "language": "en",
    "source": "AI_GENERATED",
    "is_synchronized": true,
    "text": "First acoustic chord\nWalking down the shoreline",
    "lines": [
      {
        "id": "8e3b1c24-5d39-4458-9be3-ef377e8a9390",
        "sequence": 0,
        "start_ms": 10500,
        "end_ms": 14200,
        "text": "First acoustic chord"
      },
      {
        "id": "1f2e3d4c-5b6a-7890-bcde-fa1234567890",
        "sequence": 1,
        "start_ms": 14500,
        "end_ms": 18000,
        "text": "Walking down the shoreline"
      }
    ],
    "model": "gemini-2.5-flash",
    "version": "v1",
    "error_message": null,
    "updated_at": "2026-09-27T17:40:00Z"
  }
}
```

**200 OK (Unavailable / Pending Generation)**
```json
{
  "success": true,
  "data": {
    "id": null,
    "track_id": "c8135d7d-b7ae-44cb-905a-da83e5a0d45a",
    "status": "UNAVAILABLE",
    "language": null,
    "source": "AI_GENERATED",
    "is_synchronized": false,
    "text": null,
    "lines": [],
    "model": null,
    "version": "v1",
    "error_message": null,
    "updated_at": null
  }
}
```

**404 Not Found**: Track does not exist.

---

### 2. Request Lyrics Generation

Enqueues background AI transcription and alignment using Google Gemini via Celery.

* **Method**: `POST`
* **Path**: `/api/v1/tracks/{track_id}/lyrics/generate`
* **Authentication**: Required (`Bearer <token>`)

#### Responses

**202 Accepted**
```json
{
  "success": true,
  "data": {
    "track_id": "c8135d7d-b7ae-44cb-905a-da83e5a0d45a",
    "status": "PROCESSING",
    "message": "Lyrics generation job enqueued"
  }
}
```

---

### 3. Upload / Save Manual Lyrics

Allows the track owner to supply manual lyrics or line-level synchronized timestamps.

* **Method**: `POST`
* **Path**: `/api/v1/tracks/{track_id}/lyrics`
* **Authentication**: Required (`Bearer <token>`) — must be the owner of the track.

#### Request Body
```json
{
  "text": "Full plain text lyrics if available",
  "language": "en",
  "is_synchronized": true,
  "lines": [
    {
      "sequence": 0,
      "start_ms": 5000,
      "end_ms": 9000,
      "text": "Line one lyric"
    },
    {
      "sequence": 1,
      "start_ms": 9500,
      "end_ms": 13000,
      "text": "Line two lyric"
    }
  ]
}
```

#### Validation Rules
- `lines[i].start_ms >= 0`
- `lines[i].end_ms == null || lines[i].end_ms >= lines[i].start_ms`
- `lines[i].start_ms > lines[i - 1].start_ms` (strictly non-decreasing / increasing order)
- Sequences must be consecutive starting at 0.

#### Responses
**200 OK**: Returns updated `LyricsResponse`.
**400 Bad Request**: Invalid timestamps or non-monotonic ordering (`INVALID_LYRIC_TIMESTAMPS`).
**403 Forbidden**: Caller does not own the track.
**404 Not Found**: Track does not exist.
