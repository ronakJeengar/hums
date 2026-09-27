# AI Lyrics Generation Pipeline

## 1. Overview
The Hums AI Lyrics Pipeline generates accurate plain or synchronized lyrics using Google Gemini structured JSON schemas via asynchronous Celery background tasks.

```mermaid
sequenceDiagram
    autonumber
    participant AudioSvc as AudioProcessingService
    participant Celery as Celery Worker
    participant Gemini as GeminiLyricsClient
    participant Repo as LyricsRepository
    participant Redis as Redis Cache

    Note over AudioSvc: Audio upload transcoded to READY
    AudioSvc->>Celery: generate_track_lyrics.delay(track_id)
    Celery->>Repo: update_status(PROCESSING)
    Celery->>Gemini: generate_lyrics(title, artist, duration_seconds)
    alt Gemini returns valid structured JSON
        Gemini-->>Celery: {language, is_synchronized, lines, plain_text}
        Celery->>Repo: create_or_update(status=COMPLETED, lines_data=...)
        Celery->>Redis: DELETE lyrics:{track_id}
    else Gemini unavailable / low confidence
        Gemini-->>Celery: None
        Celery->>Repo: update_status(UNAVAILABLE)
        Celery->>Redis: DELETE lyrics:{track_id}
    end
```

## 2. Structured JSON Generation & Guardrails
The `GeminiLyricsClient` leverages Gemini's structured response capability (`response_mime_type="application/json"` and `response_schema=lyrics_schema`) with the following strict constraints:
- **Timestamp Accuracy**: Start timestamps must be monotonically increasing.
- **Duration Boundary Check**: Any timestamp beyond the track's duration is rejected.
- **Fallback Rule**: If timestamps fail validation or cannot be determined reliably, the pipeline produces plain text lyrics (`is_synchronized: false`) or marks the track as `UNAVAILABLE`. It **never** manufactures fabricated timestamps.

## 3. Celery Worker Integration
- **Task**: `app.workers.lyrics_tasks.generate_track_lyrics(track_id: str)`
- **Auto-Invocation**: Automatically triggered when a track completes transcoding (`TrackStatus.READY`).
- **Idempotency**: Safe to re-trigger multiple times via `POST /api/v1/tracks/{track_id}/lyrics/generate`.
