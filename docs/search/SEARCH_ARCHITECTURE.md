# Search & Discovery Architecture

---

## 1. Design Overview

The Hums Search & Discovery subsystem provides immediate catalog discoverability across songs, creators, albums, and playlists.

```
Flutter (Mobile)
   │
   ├─► Debounced Query (300ms) with Generation Counter
   ├─► Fast Suggestion Autocomplete (150ms)
   │
   ▼
FastAPI Gateway
   │
   ├─► Redis Rate Limiter (Sliding token window)
   ├─► Redis Suggestion Cache (TTL 60s)
   │
   ▼
PostgreSQL 16
   │
   ├─► GIN Trigram Indexes (pg_trgm extension)
   ├─► Exact > Prefix > Token > Substring > Word Similarity Ranking
   └─► Privacy Visibility Enforcement (READY tracks, public/owned playlists)
```

---

## 2. PostgreSQL Full-Text & Trigram Strategy

Instead of introducing external search dependencies like Meilisearch or Elasticsearch at this stage, Hums utilizes PostgreSQL native full-text and `pg_trgm` trigram indexing:
- **Zero operational overhead:** Runs on primary database without out-of-sync indexing workers.
- **ACID Consistency:** As soon as an uploaded audio track enters `READY` status, it is immediately discoverable.
- **Devanagari & Multilingual Support:** UTF-8 case-insensitive pattern matching natively handles Hindi, Hinglish, and regional character sets.

---

## 3. Privacy & Security Rules

1. **Audio Tracks:**
   Only tracks with `status == 'READY'` are visible. Unprocessed (`UPLOADED`), processing (`PROCESSING`), or failed (`FAILED`) tracks are filtered out server-side.
2. **Playlists:**
   Playlists are only returned if `is_public == True` OR `owner_id == current_user_id`. Private playlists never leak metadata to unauthorized users.
3. **No Raw SQL:**
   All queries use parameterized SQLAlchemy Core/ORM constructs to completely eliminate SQL injection vectors.

---

## 4. Criteria for Future Meilisearch / Elasticsearch Migration

Hums will evaluate migrating to an external search engine (e.g. Meilisearch) ONLY if one of the following measurable thresholds is met:
1. Catalog size exceeds 500,000 active tracks and p95 query latency on PostgreSQL exceeds 100ms despite index tuning.
2. Search query volume begins impacting database CPU or connection pool resources required for core playback operations.
3. Complex semantic search (e.g., audio embeddings, AI lyric vector search) is introduced in post-MVP phases.
