# HUMS — Database Schema Specification

**Database Engine:** PostgreSQL 16+  
**ORM:** SQLAlchemy 2.0 (Declarative Base, Async API)  
**Migration Tool:** Alembic  
**Naming Convention:** Snake_case plural table names, explicit foreign keys, UTC timestamps.  

---

## 1. Schema Conventions & Standard Columns

Every relational table in Hums inherits from a shared base model providing:

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | Primary Key, default `gen_random_uuid()` | Universally unique entity identifier |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, default `NOW()` | Record creation timestamp in UTC |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL, default `NOW()`, auto-update | Last modification timestamp in UTC |

---

## 2. Foundation Tables (Active in Baseline)

### 2.1 `users`
Stores core user identity, credentials, and account status.

| Column | Type | Nullable | Constraints | Description |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | No | PK | Primary Key |
| `email` | `VARCHAR(255)` | No | UNIQUE, INDEX | Normalized lowercase user email |
| `username` | `VARCHAR(50)` | Yes | UNIQUE, INDEX | Unique display/handle identifier |
| `hashed_password` | `VARCHAR(255)` | No | | Securely hashed password (Argon2id/Bcrypt) |
| `full_name` | `VARCHAR(100)` | Yes | | Optional public display name |
| `avatar_url` | `VARCHAR(500)` | Yes | | S3/CDN object path for avatar |
| `bio` | `VARCHAR(500)` | Yes | | User biographical statement / acoustic profile summary |
| `is_active` | `BOOLEAN` | No | Default `TRUE` | Account activation flag |
| `is_verified` | `BOOLEAN` | No | Default `FALSE` | Email verification flag |
| `last_login_at` | `TIMESTAMPTZ` | Yes | | Timestamp of last successful credential login |
| `created_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Account creation time |
| `updated_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Last update time |

**Indexes:**
* `ix_users_email` (btree, UNIQUE): For ultra-fast login lookups.
* `ix_users_username` (btree, UNIQUE): For profile routing.

---

### 2.2 `refresh_tokens`
Maintains cryptographically secured refresh tokens for JWT session rotation.

| Column | Type | Nullable | Constraints | Description |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | No | PK | Primary Key |
| `user_id` | `UUID` | No | FK -> `users(id)` ON DELETE CASCADE | Owner of the session |
| `token_hash` | `VARCHAR(255)` | No | UNIQUE, INDEX | SHA-256 hash of the issued refresh token |
| `device_info` | `VARCHAR(255)` | Yes | | Client device identifier or User-Agent |
| `ip_address` | `VARCHAR(45)` | Yes | | Client IP address at issuance |
| `is_revoked` | `BOOLEAN` | No | Default `FALSE` | Explicit revocation flag |
| `revoked_at` | `TIMESTAMPTZ` | Yes | | Timestamp of explicit token revocation |
| `expires_at` | `TIMESTAMPTZ` | No | INDEX | Token expiration timestamp |
| `created_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Issuance timestamp |
| `updated_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Update timestamp |

**Indexes:**
* `ix_refresh_tokens_token_hash` (btree, UNIQUE): For rapid token exchange and validation.
* `ix_refresh_tokens_user_id` (btree): For cascading session revocation.
* `ix_refresh_tokens_expires_at` (btree): For background cleanup of expired tokens.

---

### 2.3 `password_reset_tokens`
Maintains single-use, cryptographically secured tokens for account password recovery.

| Column | Type | Nullable | Constraints | Description |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | No | PK | Primary Key |
| `user_id` | `UUID` | No | FK -> `users(id)` ON DELETE CASCADE | Target user account |
| `token_hash` | `VARCHAR(255)` | No | UNIQUE, INDEX | SHA-256 hash of the issued reset token |
| `is_used` | `BOOLEAN` | No | Default `FALSE` | Flag indicating if token was consumed |
| `used_at` | `TIMESTAMPTZ` | Yes | | Timestamp when password was reset |
| `expires_at` | `TIMESTAMPTZ` | No | INDEX | Expiration timestamp (15 minutes) |
| `created_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Issuance timestamp |
| `updated_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Update timestamp |

**Indexes:**
* `ix_password_reset_tokens_token_hash` (btree, UNIQUE): For rapid token lookup.
* `ix_password_reset_tokens_user_id` (btree): For user-scoped invalidation.
* `ix_password_reset_tokens_expires_at` (btree): For background pruning of expired reset tokens.

---

### 2.4 `tracks`
Stores audio tracks uploaded by authenticated users, including core acoustic and release metadata.

| Column | Type | Nullable | Constraints | Description |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | No | PK | Primary Key |
| `owner_id` | `UUID` | No | FK -> `users(id)` ON DELETE CASCADE | Track creator and owner |
| `title` | `VARCHAR(255)` | No | | Track title |
| `description` | `TEXT` | Yes | | Optional track notes, lyrics, or podcast show notes |
| `artist_name` | `VARCHAR(255)` | Yes | | Display artist or ensemble name |
| `album_name` | `VARCHAR(255)` | Yes | | Optional album or release collection name |
| `genre` | `VARCHAR(100)` | Yes | | Acoustic genre tag (e.g., Ambient, Acoustic, Podcast) |
| `duration_seconds` | `INTEGER` | Yes | | Duration in seconds (extracted by background worker) |
| `waveform_key` | `VARCHAR(500)` | Yes | | S3 storage key for normalized waveform JSON (`audio/waveforms/{track_id}.json`) |
| `status` | `VARCHAR(50)` | No | Default `'UPLOADED'`, INDEX | Track lifecycle state (`UPLOADING`, `UPLOADED`, `PROCESSING`, `READY`, `FAILED`) |
| `created_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Creation timestamp |
| `updated_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Update timestamp |

**Indexes:**
* `ix_tracks_owner_id` (btree): For user-scoped track catalog queries.
* `ix_tracks_status` (btree): For querying tracks by operational status.
* `ix_tracks_genre` (btree): For rapid candidate filtering and genre-based recommendation discovery.
* `ix_tracks_status_created_at` (btree composite): `(status, created_at DESC)` for public catalog feed queries.
* `ix_tracks_owner_created_at` (btree composite): `(owner_id, created_at DESC)` for user track listing without sorting.

---

### 2.5 `audio_files`
Stores raw and processed audio assets hosted in S3-compatible object storage.

| Column | Type | Nullable | Constraints | Description |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | No | PK | Primary Key |
| `track_id` | `UUID` | No | FK -> `tracks(id)` ON DELETE CASCADE | Associated parent track |
| `object_key` | `VARCHAR(500)` | No | INDEX | S3 storage key path (`audio/original/{user_id}/{track_id}/{file_uuid}.{ext}`) |
| `storage_provider` | `VARCHAR(50)` | No | Default `'s3'` | Storage backend (`s3`, `minio`, `r2`) |
| `original_filename` | `VARCHAR(255)` | No | | Client-supplied file name at upload |
| `mime_type` | `VARCHAR(100)` | No | | Detected and validated MIME type |
| `file_size_bytes` | `BIGINT` | No | | File size in bytes |
| `created_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Ingestion timestamp |
| `updated_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Update timestamp |

**Indexes:**
* `ix_audio_files_track_id` (btree): For track asset queries.
* `ix_audio_files_object_key` (btree): For storage key lookups.

---

### 2.6 `audio_renditions`
Stores streaming-optimized audio renditions (e.g. 192k, 128k, 64k AAC/M4A) generated by background FFmpeg workers.

| Column | Type | Nullable | Constraints | Description |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | No | PK | Primary Key |
| `track_id` | `UUID` | No | FK -> `tracks(id)` ON DELETE CASCADE | Associated parent track |
| `storage_key` | `VARCHAR(500)` | No | INDEX | S3 storage key path (`audio/processed/{track_id}/{rendition_id}.m4a`) |
| `storage_provider` | `VARCHAR(50)` | No | Default `'s3'` | Storage backend (`s3`, `minio`, `r2`) |
| `format` | `VARCHAR(50)` | No | | Container format (`m4a`) |
| `codec` | `VARCHAR(50)` | No | | Audio codec (`aac`) |
| `bitrate_kbps` | `INTEGER` | No | | Encoding bitrate in kbps (e.g. 64, 128, 192) |
| `sample_rate` | `INTEGER` | Yes | | Audio sampling rate in Hz (e.g. 44100) |
| `channels` | `INTEGER` | Yes | | Number of audio channels (e.g. 2) |
| `duration_seconds` | `INTEGER` | Yes | | Rendition duration in seconds |
| `file_size_bytes` | `BIGINT` | No | | Rendition file size in bytes |
| `created_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Generation timestamp |
| `updated_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Update timestamp |

**Indexes:**
* `ix_audio_renditions_track_id` (btree): For track renditions retrieval.
* `ix_audio_renditions_storage_key` (btree): For storage key lookups.

---

### 2.7 `processing_jobs`
Tracks asynchronous media transcoding and analysis jobs for Celery / FFmpeg workers.

| Column | Type | Nullable | Constraints | Description |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | No | PK | Primary Key |
| `track_id` | `UUID` | No | FK -> `tracks(id)` ON DELETE CASCADE | Target track to process |
| `job_type` | `VARCHAR(50)` | No | Default `'AUDIO_TRANSCODE'` | Processing task type |
| `status` | `VARCHAR(50)` | No | Default `'PENDING'`, INDEX | Job state (`PENDING`, `PROCESSING`, `COMPLETED`, `FAILED`) |
| `attempts` | `INTEGER` | No | Default `0` | Execution attempt counter |
| `error_message` | `TEXT` | Yes | | Failure diagnostic log if job fails |
| `created_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Job enqueue timestamp |
| `updated_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Job update timestamp |

**Indexes:**
* `ix_processing_jobs_track_id` (btree): For track processing job lookups.
* `ix_processing_jobs_status` (btree): For worker job queue polling.

---

### 2.8 `playlists`
Stores user-curated playlist collections with metadata and artwork references.

| Column | Type | Nullable | Constraints | Description |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | No | PK | Primary Key |
| `owner_id` | `UUID` | No | FK -> `users(id)` ON DELETE CASCADE | Playlist creator and owner |
| `name` | `VARCHAR(100)` | No | | Playlist name |
| `description` | `VARCHAR(500)` | Yes | | Optional description or curator notes |
| `cover_image_key` | `VARCHAR(500)` | Yes | | S3/MinIO object path for cover artwork |
| `is_public` | `BOOLEAN` | No | Default `FALSE` | Visibility flag |
| `created_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Playlist creation timestamp |
| `updated_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Playlist update timestamp |

**Indexes:**
* `ix_playlists_owner_id` (btree): For fast retrieval of user-owned playlists.
* `ix_playlists_owner_created_at` (btree composite): `(owner_id, created_at DESC)` for user playlist listing without sorting.

---

### 2.9 `playlist_tracks`
Ordered junction table managing track memberships and sequential playback positioning within playlists.

| Column | Type | Nullable | Constraints | Description |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | No | PK | Primary Key |
| `playlist_id` | `UUID` | No | FK -> `playlists(id)` ON DELETE CASCADE | Parent playlist |
| `track_id` | `UUID` | No | FK -> `tracks(id)` ON DELETE CASCADE | Member track |
| `position` | `INTEGER` | No | Default `0`, INDEX | Zero-based sequential ordering index |
| `added_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Timestamp when track was added to playlist |

**Constraints & Indexes:**
* `uq_playlist_tracks_playlist_track` (UNIQUE): Enforces that a track can appear only once in a playlist.
* `ix_playlist_tracks_playlist_id` (btree): For fetching all tracks belonging to a playlist.
* `ix_playlist_tracks_track_id` (btree): For cascading lookups.
* `ix_playlist_tracks_position` (btree): For ordered traversal and reordering.
* `ix_playlist_tracks_playlist_id_position` (btree composite): `(playlist_id, position ASC)` for ordered track retrieval within playlists without sorting.

---

### 2.10 `recommendation_sets`
Stores generated recommendation batches for users with versioning and time-to-live expiration.

| Column | Type | Nullable | Constraints | Description |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | No | PK | Primary Key |
| `user_id` | `UUID` | No | FK -> `users(id)` ON DELETE CASCADE, INDEX | Target user |
| `algorithm_version` | `VARCHAR(50)` | No | Default `'v1-hybrid'` | Recommendation algorithm identifier |
| `generated_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Generation timestamp |
| `expires_at` | `TIMESTAMPTZ` | Yes | INDEX | Cache expiration timestamp |
| `created_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Record creation timestamp |
| `updated_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Record update timestamp |

**Indexes:**
* `ix_recommendation_sets_user_id` (btree): For fast retrieval of user's active recommendation set.
* `ix_recommendation_sets_expires_at` (btree): For background cleanup of stale recommendation sets.

---

### 2.11 `recommendation_items`
Stores ordered track recommendations linked to a parent recommendation set.

| Column | Type | Nullable | Constraints | Description |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | No | PK | Primary Key |
| `recommendation_set_id` | `UUID` | No | FK -> `recommendation_sets(id)` ON DELETE CASCADE, INDEX | Parent recommendation batch |
| `track_id` | `UUID` | No | FK -> `tracks(id)` ON DELETE CASCADE, INDEX | Recommended track |
| `position` | `INTEGER` | No | Default `0` | Zero-based presentation order |
| `created_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Timestamp when item was added |
| `updated_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Timestamp when item was updated |

**Constraints & Indexes:**
* `uq_recommendation_items_set_track` (UNIQUE): Enforces deduplication of a track within a recommendation set.
* `ix_recommendation_items_recommendation_set_id` (btree): For fetching all items in a set.
* `ix_recommendation_items_track_id` (btree): For cascading lookups.

---

### 2.12 `user_devices`
Stores registered push notification device tokens for multi-device delivery.

| Column | Type | Nullable | Constraints | Description |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | No | PK, Default `gen_random_uuid()` | Primary Key |
| `user_id` | `UUID` | No | FK -> `users(id)` ON DELETE CASCADE, INDEX | Device owner |
| `device_token` | `VARCHAR(500)` | No | UNIQUE, INDEX | FCM or APNs device token |
| `platform` | `VARCHAR(20)` | No | Default `'ANDROID'` | `ANDROID`, `IOS`, or `WEB` |
| `device_name` | `VARCHAR(100)` | Yes | | Client device model name |
| `app_version` | `VARCHAR(50)` | Yes | | Client app version string |
| `is_active` | `BOOLEAN` | No | Default `TRUE` | Active token flag |
| `last_seen_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Timestamp of last token registration |
| `created_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Timestamp when device registered |
| `updated_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Timestamp when device updated |

**Indexes:**
* `ix_user_devices_device_token` (UNIQUE): Fast token upsert and deduplication.
* `ix_user_devices_user_id_is_active` (btree composite): Active device querying for push multicast.

---

### 2.13 `notifications`
Stores in-app notifications and push delivery history for user inboxes.

| Column | Type | Nullable | Constraints | Description |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | No | PK, Default `gen_random_uuid()` | Primary Key |
| `user_id` | `UUID` | No | FK -> `users(id)` ON DELETE CASCADE, INDEX | Target recipient |
| `type` | `VARCHAR(50)` | No | INDEX | `NEW_RELEASE`, `PLAYLIST_UPDATE`, `UPLOAD_COMPLETE`, etc. |
| `title` | `VARCHAR(255)` | No | | Notification header title |
| `body` | `TEXT` | No | | Notification message text |
| `data` | `JSONB` | Yes | Default `'{}'::jsonb` | Arbitrary payload with deep link routing metadata |
| `is_read` | `BOOLEAN` | No | Default `FALSE` | Read / unread status indicator |
| `read_at` | `TIMESTAMPTZ` | Yes | | Timestamp when marked as read |
| `idempotency_key` | `VARCHAR(255)` | Yes | UNIQUE, INDEX | Optional deduplication key |
| `created_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Creation timestamp |
| `updated_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Modification timestamp |

**Indexes:**
* `ix_notifications_user_id_created_at` (btree composite): Paginated inbox querying (newest first).
* `ix_notifications_user_id_is_read` (btree composite): Fast unread count aggregation.
* `ix_notifications_idempotency_key` (UNIQUE): Prevents duplicate notification events.

---

### 2.14 `notification_preferences`
Controls global push delivery toggles and category subscriptions per user.

| Column | Type | Nullable | Constraints | Description |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `UUID` | No | PK, Default `gen_random_uuid()` | Primary Key |
| `user_id` | `UUID` | No | FK -> `users(id)` ON DELETE CASCADE, UNIQUE, INDEX | Target user |
| `push_enabled` | `BOOLEAN` | No | Default `TRUE` | Master push notification toggle |
| `new_releases_enabled` | `BOOLEAN` | No | Default `TRUE` | New artist releases category |
| `playlist_updates_enabled` | `BOOLEAN` | No | Default `TRUE` | Playlist modifications category |
| `recommendations_enabled` | `BOOLEAN` | No | Default `TRUE` | Smart AI mixes category |
| `processing_updates_enabled` | `BOOLEAN` | No | Default `TRUE` | Upload/transcode finished category |
| `created_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Creation timestamp |
| `updated_at` | `TIMESTAMPTZ` | No | Default `NOW()` | Modification timestamp |

---

### 2.15 Search Architecture & Trigram Indexes
To support high-throughput, typo-tolerant, and multilingual relevance queries across catalog tracks, artists, and playlists without third-party external search clusters, Hums enables the PostgreSQL `pg_trgm` extension and creates dedicated Generalized Inverted Index (GIN) trigram indexes.

**Database Extensions:**
* `CREATE EXTENSION IF NOT EXISTS pg_trgm;`

**Search Trigram Indexes:**
* `ix_tracks_title_trgm` (GIN, `title gin_trgm_ops`): Accelerates substring, prefix, and similarity queries on track titles.
* `ix_tracks_artist_name_trgm` (GIN, `artist_name gin_trgm_ops`): Accelerates search over artist names across tracks.
* `ix_tracks_album_name_trgm` (GIN, `album_name gin_trgm_ops`): Accelerates album title queries.
* `ix_tracks_genre_trgm` (GIN, `genre gin_trgm_ops`): Accelerates genre keyword filtering.
* `ix_playlists_name_trgm` (GIN, `name gin_trgm_ops`): Accelerates playlist title searches.
* `ix_playlists_description_trgm` (GIN, `description gin_trgm_ops`): Searches playlist descriptions.
* `ix_users_username_trgm` (GIN, `username gin_trgm_ops`): Creator/artist handle searches.
* `ix_users_full_name_trgm` (GIN, `full_name gin_trgm_ops`): Creator/artist display name searches.

**Multi-Criteria Relevance Formula:**
* Exact Match (`LOWER(col) == query`): Weight 100.0 (title), 80.0 (artist), 100.0 (playlist).
* Prefix Match (`col ILIKE 'query%'`): Weight 50.0 (title), 40.0 (artist), 50.0 (playlist).
* Substring Match (`col ILIKE '%query%'`): Weight 25.0 (title), 20.0 (artist), 25.0 (playlist).
* Trigram Word Similarity (`word_similarity(query, col)`): Weight 20.0 (title), 15.0 (artist), 20.0 (playlist).
* Tie-breaker: `created_at DESC, id DESC` guaranteeing deterministic pagination.

---

## 3. Planned Future Tables (Roadmap)

These schemas are architecturally planned for subsequent features and are intentionally NOT created during project foundation to avoid premature schema bloat:

* `user_profiles` (Extended biographical and acoustic preference information)
* `artists` (Verified artist entities and discography links)
* `albums` (Collections of musical tracks)
* `podcasts` & `episodes` (Serialized talk shows and chapter markers)
* `likes` (Polymorphic favorites for tracks, albums, and playlists)
* `listening_history` (Continuous playback logs for analytics and recommendations)



