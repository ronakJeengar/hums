# Hums Database Schema & Search Indexes

---

## 1. Relational Tables

### 1.1 `tracks`
Core audio catalog table.
- `id` (UUID, PK)
- `owner_id` (UUID, FK -> `users.id`, Indexed)
- `title` (VARCHAR(255), Not Null)
- `description` (TEXT, Nullable)
- `artist_name` (VARCHAR(255), Nullable)
- `album_name` (VARCHAR(255), Nullable)
- `genre` (VARCHAR(100), Nullable)
- `duration_seconds` (INTEGER, Nullable)
- `waveform_key` (VARCHAR(500), Nullable)
- `status` (VARCHAR(50), Not Null, Indexed: `UPLOADED`, `PROCESSING`, `READY`, `FAILED`)
- `created_at` (TIMESTAMPTZ, Default `NOW()`)
- `updated_at` (TIMESTAMPTZ, Default `NOW()`)

### 1.2 `playlists`
User playlists table.
- `id` (UUID, PK)
- `owner_id` (UUID, FK -> `users.id`, Indexed)
- `name` (VARCHAR(255), Not Null)
- `description` (TEXT, Nullable)
- `cover_image_key` (VARCHAR(500), Nullable)
- `is_public` (BOOLEAN, Default `FALSE`, Indexed)
- `created_at` (TIMESTAMPTZ, Default `NOW()`)
- `updated_at` (TIMESTAMPTZ, Default `NOW()`)

### 1.3 `users`
User accounts and artist profiles.
- `id` (UUID, PK)
- `email` (VARCHAR(255), Unique, Indexed)
- `username` (VARCHAR(50), Unique, Indexed)
- `full_name` (VARCHAR(100), Nullable)
- `avatar_url` (VARCHAR(500), Nullable)
- `bio` (VARCHAR(500), Nullable)
- `is_active` (BOOLEAN, Default `TRUE`)

---

## 2. GIN Trigram Search Indexes

All indexes are created with the `pg_trgm` extension using Generalized Inverted Indexing (`gin_trgm_ops`):

| Index Name | Table | Target Column | Purpose |
| :--- | :--- | :--- | :--- |
| `ix_tracks_title_trgm` | `tracks` | `title` | Substring, prefix, and typo-tolerant track search |
| `ix_tracks_artist_name_trgm` | `tracks` | `artist_name` | Fast artist name filtering and aggregation |
| `ix_tracks_album_name_trgm` | `tracks` | `album_name` | Fast album grouping and search |
| `ix_tracks_genre_trgm` | `tracks` | `genre` | Fast genre filtering |
| `ix_playlists_name_trgm` | `playlists` | `name` | Playlist title substring and fuzzy search |
| `ix_playlists_description_trgm` | `playlists` | `description` | Playlist description substring matching |
| `ix_users_username_trgm` | `users` | `username` | Creator username lookup |
| `ix_users_full_name_trgm` | `users` | `full_name` | Creator display name search |
