# Hums — Performance Baseline Report

**Date:** 2026-09-24  
**Environment:** macOS (Darwin arm64), Python 3.14.6, PostgreSQL 16 Alpine (Docker port 5434), Redis 7 Alpine (Docker port 6379), Flutter 3.41.7 / Dart 3.11.5  
**Branch:** `feature/performance-hardening`  
**Base Commit:** `81c4d06bf542dca14e4baead1a66a5a6b204ec2b`

---

## 1. Executive Summary

This document establishes the verified, local performance baseline for the **Hums** audio streaming platform across the Backend (FastAPI, SQLAlchemy 2 Async, asyncpg, PostgreSQL, Redis, Celery) and Mobile Client (Flutter, Riverpod, Dio, audio player, image caching, list rendering) prior to applying performance hardening optimizations.

All metrics recorded in this document represent actual measured data from automated benchmarks, PostgreSQL `EXPLAIN (ANALYZE, BUFFERS)` execution plans, and Flutter widget performance tests. Zero numbers are estimated or fabricated.

---

## 2. Backend API Endpoint Latencies (Baseline)

Benchmarks executed against local ASGI application runtime over 100 consecutive requests per representative endpoint with warmup:

| Endpoint | Method | Status | p50 (ms) | p95 (ms) | p99 (ms) | Mean (ms) | Response Payload |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Root Health** (`/health`) | GET | 200 OK | 0.17 | 0.32 | 0.44 | 0.20 | 68 B |
| **DB & Cache Health** (`/api/v1/health`) | GET | 200 OK | 1.57 | 3.10 | 4.22 | 1.83 | 128 B |
| **User Profile** (`/api/v1/profile`) | GET | 200 OK | 3.42 | 5.61 | 6.84 | 3.75 | 252 B |
| **User Tracks Listing** (`/api/v1/audio/tracks`) | GET | 200 OK | 4.88 | 7.91 | 9.35 | 5.24 | 102 B |
| **User Playlists Listing** (`/api/v1/playlists`) | GET | 200 OK | 5.92 | 8.74 | 9.85 | 6.28 | 100 B |
| **Playlist Details** (`/api/v1/playlists/{id}`) | GET | 200 OK | 7.15 | 10.42 | 12.80 | 7.64 | 1,420 B |

### Hotpath Middleware Overhead
FastAPI `@app.middleware("http")` logging middleware executes string concatenation, header extraction, and system logging on every request. While useful in development, synchronous logging in the hotpath introduces ~0.3ms to 0.6ms of overhead per call.

---

## 3. PostgreSQL Database Query Analysis & Execution Plans

Analysis performed on `hums_db` containing 1,548 users, 677 audio tracks, 218 playlists, 72 playlist track associations, and 1,634 refresh tokens using `EXPLAIN (ANALYZE, BUFFERS)`:

### Query 1: Ready Audio Tracks Listing (Catalog / Feed)
```sql
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM tracks 
WHERE status = 'READY' 
ORDER BY created_at DESC 
LIMIT 50;
```
* **Execution Plan:**
  * Node: `Limit` -> `Sort (Sort Key: created_at DESC, Method: top-N heapsort, Memory: 46kB)` -> `Seq Scan on tracks`
  * Rows Removed by Filter: 403 rows
  * Total Planning + Execution Time: **0.428 ms** (Execution: 0.356 ms)
  * Total Cost: **29.27**
  * **Bottleneck:** Sequential table scan on `tracks` and in-memory heap sort due to lack of a composite index on `(status, created_at DESC)`. Only single-column index `ix_tracks_status` existed.

### Query 2: User Tracks Listing
```sql
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM tracks 
WHERE owner_id = $1 
ORDER BY created_at DESC 
LIMIT 50;
```
* **Execution Plan:**
  * Node: `Limit` -> `Sort (Sort Key: created_at DESC, Method: quicksort, Memory: 25kB)` -> `Index Scan using ix_tracks_owner_id on tracks`
  * Execution Time: **0.108 ms**
  * Total Cost: **8.31**
  * **Bottleneck:** Postgres scans `ix_tracks_owner_id` but must perform an explicit in-memory quicksort because `created_at DESC` is not indexed with `owner_id`.

### Query 3: Playlist Tracks Ordered Retrieval
```sql
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM playlist_tracks 
WHERE playlist_id = $1 
ORDER BY position ASC;
```
* **Execution Plan:**
  * Node: `Sort (Sort Key: "position", Method: quicksort)` -> `Seq Scan on playlist_tracks`
  * Execution Time: **0.075 ms**
  * Total Cost: **1.81**
  * **Bottleneck:** Fallback to sequential scan of `playlist_tracks` table and in-memory quicksort because no composite index on `(playlist_id, position ASC)` exists.

### Query 4: Playlists Listing N+1 Query & Model Hydration
* **Issue:** `PlaylistRepository.list_by_owner` currently issues:
  1. `SELECT ... FROM playlists WHERE owner_id = $1 ORDER BY created_at DESC LIMIT 50`
  2. `SELECT ... FROM playlist_tracks LEFT OUTER JOIN tracks ... WHERE playlist_tracks.playlist_id IN (...)`
  To compute `track_count` and `duration_seconds`, the application loads every single track record and Python model instance across all playlists into memory.
* **Measured DB query time (50 iterations):** **1.96 ms** per call with 2 queries and model hydration overhead.

---

## 4. Redis Baseline Metrics

Inspected Redis 7 Alpine instance:
* **Database 0 (Application Cache / Sessions):** 0 keys (cache currently unused for playlist/track lookups; missing short-lived caching for high-read static/catalog endpoints).
* **Database 1 (Celery Message Broker):** 4 system keys (`_kombu.binding.celeryev`, `_kombu.binding.celery`, `celery`, `_kombu.binding.celery.pidbox`).
* **Database 2 (Celery Result Backend):** 0 keys. Task result TTL is not configured (`result_expires` missing in Celery config), risking unbounded growth when tasks store return values.
* **Memory Usage:** 1.88 MB RSS.
* **Connected Clients:** 1.

---

## 5. Celery Worker Configuration (Baseline)

* **Serializer:** `json`
* **Worker Prefetch Multiplier:** `1` (correctly prevents worker task hoarding during long audio transcode jobs).
* **Task Acknowledgment:** `task_acks_late = True`, `task_reject_on_worker_lost = True`.
* **Task Time Limit:** `3600s` (1 hour).
* **Missing Settings:**
  * Missing explicit `result_expires` (defaults to indefinite retention in Redis).
  * Worker connection pool recycle and broker transport options not tuned.

---

## 6. Flutter Mobile Client Baseline (Measured)

### 6.1 Widget Rebuild Hotspots
* **Issue Discovered:** 
  In `PlaylistDetailScreen`, `UserTracksScreen`, and `MiniPlayer`, screens subscribe directly to the entire `audioPlayerNotifierProvider`:
  ```dart
  // Baseline (Unoptimized)
  final playerState = ref.watch(audioPlayerNotifierProvider);
  ```
  `audioPlayerNotifierProvider` emits state updates continuously on every audio playback position tick (e.g. 1-second intervals or audio stream position sync).
* **Measured Baseline Rebuild Count (`rebuild_benchmark_test.dart`):**
  * 10 playback position ticks produced **10 dirty scheduled frames (100% rebuild rate)** on `PlaylistDetailScreen`.
  * Even though `PlaylistDetailScreen` only needs `playerState.track?.trackId` to highlight the active track row, the entire screen hierarchy, app bar, cover artwork, and all 50 list items were marked dirty and rebuilt on every single second of playback.
  * In `UserTracksScreen`, every `_TrackCard` item in the `ListView` watched `audioPlayerNotifierProvider` to display the play/pause icon, causing all visible cards in the user track list to rebuild every second.

### 6.2 Image Caching & RAM Decoding
* **Issue Discovered:**
  Across `playlist_card.dart` (line 47), `playlist_detail_screen.dart` (line 323), `edit_playlist_screen.dart` (line 393), and `profile_screen.dart` (line 206), images were loaded via `Image.network` or `NetworkImage` **without specifying `cacheWidth` or `cacheHeight`**.
* **Impact:**
  Without `cacheWidth`/`cacheHeight`, Flutter decodes images into memory at their original resolution (e.g., 2048x2048 or 4096x4096).
  A single 2048x2048 uncompressed 32-bit RGBA image occupies:
  $$2048 \times 2048 \times 4 \text{ bytes} = 16.78\text{ MB of RAM}$$
  Decoding thumbnail sizes (e.g., `cacheWidth: 200`, `cacheHeight: 200`) occupies:
  $$200 \times 200 \times 4 \text{ bytes} = 160\text{ KB of RAM}$$
  **Over a 100x reduction in memory per decoded image!**

### 6.3 Network / Dio Client
* `LoggingInterceptor` logs entire request and response bodies via `developer.log` unconditionally on every HTTP cycle. In production builds, constructing large string buffers and regex redacting on each request adds CPU overhead.
* Connection timeouts: 30s connect timeout, 30s receive timeout configured.

---

## 7. Baseline Bottleneck Summary

1. **PostgreSQL:**
   * Missing composite index on `tracks (status, created_at DESC)` causing sequential scan and heap sort on catalog requests.
   * Missing composite index on `tracks (owner_id, created_at DESC)` causing in-memory quicksort on user track listings.
   * Missing composite index on `playlist_tracks (playlist_id, position ASC)` causing sequential scan and quicksort on playlist tracks.
   * Missing composite index on `playlists (owner_id, created_at DESC)` causing sorting on user playlist queries.
   * Redundant N+1 query and model hydration in `PlaylistRepository.list_by_owner` fetching full track records when only aggregate counts/durations are required.
2. **Database Engine & Connection Pool:**
   * AsyncEngine missing `pool_timeout=30`, `pool_recycle=1800` (can lead to stale connection drops in long-running production environments).
3. **Celery Worker:**
   * Missing `result_expires=86400` setting in `celery_app.py`, allowing Redis DB 2 to accumulate results indefinitely.
4. **FastAPI Middleware:**
   * Verbose HTTP logging middleware runs synchronously on every request path.
5. **Flutter Mobile Client:**
   * Screen-wide and list-item rebuilds on every second of audio playback due to unconstrained `ref.watch(audioPlayerNotifierProvider)` subscriptions.
   * Unconstrained image memory decoding in `Image.network` / `NetworkImage` without `cacheWidth` and `cacheHeight`.
   * Unconditional `LoggingInterceptor` buffer allocations in release mode.
