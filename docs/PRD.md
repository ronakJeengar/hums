# HUMS — Product Requirements Document (PRD)

**Document Version:** 1.0.0  
**Status:** Draft / Active  
**Author:** Lead Software Architect & Senior Full-Stack Engineer  
**Last Updated:** 2026-09-17  

---

## 1. Product Vision

**Hums** is an independent, modern, audio-first streaming and podcast platform designed to deliver an intimate, warm, and fast listening experience. Unlike generic audio apps cluttered with visual noise, Hums prioritizes pristine audio fidelity, acoustic warmth, effortless audio discovery, creator uploads, and clean community listening.

Hums operates as a completely autonomous ecosystem with its own user identity, media processing pipelines, databases, and client experiences.

### Key Pillars
* **Warm & Aesthetic:** Visually refined, audio-centric interface featuring rich acoustics-inspired palettes rather than neon-cluttered dark modes.
* **Frictionless Playback & Upload:** Instant playback start, adaptive audio streaming (HLS), and background transcoding via dedicated worker pipelines.
* **Creator-Friendly:** Effortless uploading, automated waveform visualization, metadata extraction, and episode management.
* **Intelligent & Modular:** Architectural readiness for future AI-powered transcript generation, genre tagging, and contextual recommendations.

---

## 2. Target Audience

1. **Active Listeners:** Individuals seeking distraction-free music, curated ambient sounds, and deep podcast conversations.
2. **Independent Audio Creators & Musicians:** Artists seeking simple upload workflows, track analytics, and direct listener reach.
3. **Podcasters & Storytellers:** Show hosts requiring serialized episode management, RSS distribution, and future automated transcripts.

---

## 3. Core User Journeys

### 3.1 Listener Journey
1. **Onboarding:** Register with email/password, complete a minimal profile, set audio preferences.
2. **Discovery:** Explore trending tracks, curated playlists, featured podcasts, and new artist releases.
3. **Playback:** Tap to play, seamless background audio playback, persistent mini-player, full-screen player with live waveform.
4. **Library Management:** Like tracks, create custom playlists, access listening history, and follow artists/podcasts.

### 3.2 Creator / Uploader Journey
1. **Upload Initiation:** Select an audio file (MP3, WAV, FLAC, AAC) on mobile or web.
2. **Metadata Input:** Add title, artist, album, genre, release date, artwork, and show notes.
3. **Asynchronous Processing:** Track upload progress while Celery workers extract duration/bitrate, transcode to multi-bitrate HLS streams, and generate waveform peaks.
4. **Publishing:** Track goes live immediately on CDN once processing completes.

---

## 4. Minimum Viable Product (MVP) Scope

The MVP encompasses the foundational pillars necessary for a viable, delightful product:

| Module | Features in MVP Scope |
| :--- | :--- |
| **Foundation & DevOps** | Clean architecture (FastAPI + Flutter), Dockerized local infrastructure (PostgreSQL, Redis, MinIO), CI-ready configs. |
| **Authentication & Sessions** | Self-sovereign user registration, credential login, JWT access token (30m) with `jti`, SHA-256 hashed refresh token with session rotation (7d), explicit logout revocation, `/api/v1/auth/me`, single-use enumeration-safe password reset flow, Flutter secure storage, transparent Dio interceptor with mutex refresh. |
| **User Profile & Avatar** | Authenticated profile retrieval (`GET /api/v1/profile`), partial profile update (`PATCH /api/v1/profile`), safe email update with uniqueness checks, name/bio validation, avatar upload/replace with image validation & processing (Pillow WebP) to S3/MinIO, avatar deletion, Flutter Profile and Edit Profile screens. |
| **Audio Storage & Ingestion** | S3/MinIO upload abstraction, file validation (format, size limits), DB recording. |
| **Audio Processing Pipeline** | Celery + Redis workers, FFmpeg metadata extraction, waveform generation, transcode pipeline. |
| **Playback & Streaming** | CDN-backed stream delivery, Flutter audio playback engine, mini-player, full player with waveform scrubbing. |
| **Playlists & Interactions** | User-owned playlists, CRUD endpoints, add/remove tracks, atomic track reordering, cover artwork upload/removal (S3/MinIO), total duration and track count derivation, Flutter playlist management (lists, details, reordering, creation, editing), and queue playback integration (`playQueue`, `skipToNext`, `skipToPrevious`, auto-advance on track completion). |
| **Podcasts Foundation** | Shows and episodes entity models, episode listing and playback. |
| **AI Recommendations** | Multi-signal backend recommendation engine (`for-you`, `genre`, `trending`, `discover`), modular candidate generation (genre, artist, popularity, recency), deterministic scoring with normalized weights, optional Gemini AI semantic re-ranking with resilient deterministic fallback, diversity enforcement (per-artist and per-genre caps), Redis caching (TTL 300s) with concurrent locking & debouncing, Celery background regeneration, PostgreSQL persistence (`recommendation_sets`, `recommendation_items`), and Flutter Home carousels with queue playback. |
| **Push Notifications & Inbox** | Multi-device registration (`user_devices`), category preferences (`notification_preferences`), Celery asynchronous delivery workers with exponential backoff, pluggable `PushProvider` (`FCMPushProvider`, `MockPushProvider`), automated stale token deactivation, in-app notification inbox with read tracking, unread count badge, pull-to-refresh, deep linking into tracks and playlists, and Flutter widget previews. |
| **Catalog Search & Discovery** | Backend-driven full-text, substring, and trigram-ranked relevance search (`GET /api/v1/search`), autocomplete suggestions (`GET /api/v1/search/suggestions`), Redis-backed sliding-window rate limiting and caching, `pg_trgm` PostgreSQL extension with 8 GIN indexes, multi-criteria scoring (exact > prefix > substring > trigram typo tolerance) across songs, artists, albums, playlists, podcasts, and episodes, privacy isolation (READY tracks only, public/owned playlists), debounced Flutter search UI (300ms) with race condition immunity, persistent local recent searches with individual removal and clear-all, category filter chips, global audio playback integration, and multi-screen Widget Previews. |

---

## 5. Future Roadmap (Post-MVP)

The following features are explicitly planned for future phases and **MUST NOT** be implemented during the current phase:

* **AI Transcript Generation:** Speech-to-text podcast transcription and searchable timestamps using Gemini audio analysis.
* **Live Presence & Listen-Together:** WebSocket-backed synchronized group listening rooms.
* **Advanced Elastic / Vector Search:** Semantic track search and lyric querying.
* **Offline Caching:** Encrypted on-device track caching for offline mobile playback.

---

## 6. Non-Functional Requirements

* **Latency:** API response times < 100ms for p95 requests (excluding cold audio chunk downloads).
* **Availability:** 99.9% uptime target for the API backend.
* **Audio Transcoding:** Background processing turnaround < 60 seconds for a 5-minute track.
* **Security:** End-to-end token validation, zero plaintext credentials, role-based resource authorization, file upload sanitization.
* **Scalability:** Stateless API containers horizontally scalable behind an application load balancer.
