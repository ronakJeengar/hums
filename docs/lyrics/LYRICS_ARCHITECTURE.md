# Hums Lyrics Architecture

## 1. Overview
The Lyrics & Synchronized Lyrics system in Hums delivers real-time, line-level synchronized lyric highlighting, tap-to-seek audio playback control, smooth automated scrolling with manual interaction override, offline storage caching for downloaded tracks, and automated AI generation via Google Gemini structured JSON schemas executed in Celery background workers.

```mermaid
flowchart TD
    subgraph Client ["Flutter Mobile Client"]
        FP["FullPlayerScreen"] -->|Taps Lyrics Chip/Icon| LS["LyricsScreen"]
        LS -->|Watches Line Index| ALI["activeLyricLineIndexProvider"]
        ALI -->|O(log N) Binary Search| LE["LyricsEntity"]
        ALI -->|Subscribes to Position| APN["audioPlayerNotifierProvider"]
        LS -->|Tap Line to Seek| APN
        LS -->|Fetches / Polls| LN["lyricsNotifierProvider"]
        LN --> LR["LyricsRepositoryImpl"]
        LR -->|Check First| LLD["LyricsLocalDataSource<br/>(Disk: downloads/{userId}/{trackId}/lyrics.json)"]
        LR -->|Fetch Remote| LRD["LyricsRemoteDataSource<br/>(Dio ApiClient)"]
    end

    subgraph Backend ["FastAPI Backend"]
        LRD --> API["/api/v1/tracks/{track_id}/lyrics"]
        API --> Svc["LyricsService"]
        Svc -->|Cache Check / Invalidate| RC["Redis (lyrics:{track_id})"]
        Svc --> DB[(PostgreSQL)]
        API -->|POST /generate| CW["Celery Worker<br/>generate_track_lyrics"]
        CW --> AI["GeminiLyricsClient<br/>(Structured Output API)"]
        AI --> Svc
    end
```

## 2. Core Separation of Concepts
Hums strictly separates:
- **Plain Lyrics**: Unsynchronized verses, chorus blocks, and song text without time alignment.
- **Synchronized Lyrics**: Timestamped sequences of individual lyric lines containing strict 0-indexed sequence numbering, monotonically increasing millisecond start markers (`start_ms`), and optional line completion boundaries (`end_ms`).
- **No Hallucinated Timestamps**: If the AI model or manual input lacks confident, reliable line timings, the system gracefully falls back to plain lyrics rather than inventing fabricated timestamps.

## 3. High-Performance Mobile UI Mechanics
- **Active Line Lookup ($O(\log N)$)**: A binary search over the ordered `start_ms` lines guarantees immediate lookup even for long lyrical tracks or transcripts.
- **Elimination of 60fps Screen Rebuilds**: The `activeLyricLineIndexProvider` watches audio player milliseconds but returns an integer index. Riverpod's equality comparison halts listener notifications if the index has not changed, avoiding 60 FPS widget rebuilds.
- **Auto-Scroll with Smart Manual Override**: Auto-scroll smoothly centers the active line. When the user manually scrolls or touches the viewport, auto-scroll pauses and reveals a floating "Jump to current line" button. An inactivity timer resumes auto-scrolling automatically after 5 seconds of idle time.
- **Track Transition Resilience**: Opening lyrics while listening tracks automatically re-evaluates the active track ID when skipping or auto-advancing to the next song without leaving the lyrics viewport.

## 4. Offline Storage Integration
- For tracks downloaded for offline listening, lyrics are saved alongside audio at `downloads/{userId}/{trackId}/lyrics.json`.
- When deleting a track from offline downloads, `DownloadFileManager.deleteTrackFiles` recursively purges the directory, ensuring no orphaned JSON files remain.
