# Changelog

All notable changes to the **Hums** project are documented in this file.

---

## [Unreleased] - feature/search-discovery

### Added
- **Native PostgreSQL Search Engine:** Integrated `pg_trgm` extension with 8 GIN trigram indexes (`ix_tracks_title_trgm`, `ix_tracks_artist_name_trgm`, `ix_tracks_album_name_trgm`, `ix_tracks_genre_trgm`, `ix_playlists_name_trgm`, `ix_playlists_description_trgm`, `ix_users_username_trgm`, `ix_users_full_name_trgm`).
- **Catalog Search API (`GET /api/v1/search`):** Unified multi-entity search across tracks, artists, albums, playlists, podcasts, and episodes with exact, prefix, substring, and typo-tolerant word similarity ranking.
- **Autocomplete Suggestions API (`GET /api/v1/search/suggestions`):** Fast candidate completion endpoint cached in Redis with short TTL and authorization-aware filtering.
- **Sliding-Window Rate Limiting:** Redis-backed sliding window rate limiter enforcing 60 req/min for search and 120 req/min for suggestions with graceful fail-open protection.
- **Flutter Search Experience:**
  - `SearchScreen` with debounced search bar (300ms) and generation counter for race-condition immunity.
  - Persistent Recent Searches using `FlutterSecureStorage` with deduplication, individual removal, and clear-all.
  - Interactive Autocomplete Suggestions list.
  - Filter chips for All, Songs, Artists, Albums, Playlists, Podcasts, and Episodes.
  - Category sections with "See all" pagination headers.
  - Direct global audio player playback on song tap.
  - Empty state with spellcheck and discovery guidance.
  - Error state with Retry button preserving query.
  - Multi-screen Flutter widget previews.
- **Comprehensive Test Suites:**
  - 13 backend unit and integration search tests in `backend/tests/test_search.py`.
  - Scalability and execution plan benchmark test suite in `backend/tests/test_search_performance.py`.
  - 28 Flutter unit, repository, notifier, and widget tests in `mobile/test/features/search/`.
