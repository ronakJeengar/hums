# Hums Architecture Specification

---

## 1. High-Level Architecture Overview

**Hums** is an autonomous, high-fidelity audio streaming and discovery platform engineered with a feature-first Flutter mobile application and a high-performance asynchronous FastAPI backend supported by PostgreSQL, Redis, and S3-compatible object storage.

```
                    ┌────────────────────────┐
                    │      Flutter App       │
                    │ (Riverpod 2.x Clean UI)│
                    └───────────┬────────────┘
                                │
                          HTTP REST API
                                │
                                ▼
                    ┌────────────────────────┐
                    │     FastAPI Server     │
                    │  (RateLimit + Routing) │
                    └─────┬────────────┬─────┘
                          │            │
             Search Query │            │ Cache / Rate Limit
                          ▼            ▼
               ┌────────────────┐   ┌────────────────┐
               │   PostgreSQL   │   │     Redis      │
               │ (pg_trgm + GIN)│   │ (Token Window) │
               └────────────────┘   └────────────────┘
                          │
                   Ranked Results
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
      Global           Offline         Recent
      Player          Downloads       Searches
```

---

## 2. Search & Discovery Subsystem

### 2.1 Backend Pipeline
* **Engine:** Native PostgreSQL Full-Text and Trigram Similarity Search via `pg_trgm` extension.
* **Indexes:** 8 GIN trigram indexes (`gin_trgm_ops`) on:
  - `tracks.title`, `tracks.artist_name`, `tracks.album_name`, `tracks.genre`
  - `playlists.name`, `playlists.description`
  - `users.username`, `users.full_name`
* **Scoring Strategy:**
  - Exact Title / Name Match: `100.0`
  - Exact Artist Match: `80.0`
  - Prefix Match: `50.0`
  - Substring Match: `25.0`
  - Trigram Similarity: `word_similarity(query, field) * 20.0` (threshold > `0.35`)
* **Privacy & Isolation:**
  - Tracks: Strictly restricted to `status == 'READY'`. Non-ready or failed uploads are completely omitted.
  - Playlists: Filtered by `is_public == True OR owner_id == current_user_id`.
* **Rate Limiting:**
  - `/api/v1/search`: 60 requests/minute per client token or IP with sliding Redis window.
  - `/api/v1/search/suggestions`: 120 requests/minute per client token or IP.
  - Gracefully degrades (fails open) if Redis is temporarily unreachable.
* **Caching:**
  - Autocomplete query suggestions cached in Redis (`search:suggestions:<hash>:<limit>`, TTL 60s).
  - Public entity results cached without leaking user-private content.

### 2.2 Client Architecture (Flutter)
* **Debounce Engine:** 300ms debounce timer with atomic generation counters to eliminate asynchronous race conditions.
* **Autocomplete:** 150ms debounce fetching lightweight suggestions from `/api/v1/search/suggestions`.
* **Recent Searches:** Stored in hardware-encrypted local storage via `FlutterSecureStorage` (key: `hums_recent_searches_v1`), capped at 10 items, deduplicated, newest first.
* **Categories:** All, Songs, Artists, Albums, Playlists, Podcasts, Episodes.
* **Global Integrations:**
  - Tapping a song routes directly to `audioPlayerNotifierProvider.playTrack(...)` with queue and playback history tracking.
  - MiniPlayer persistent at bottom.
  - Playlist tiles route directly to `/playlists/:id`.
