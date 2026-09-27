# Likes & Favorites Data Model Specification

## 1. Relational Schema Design

Likes in Hums are persisted in a dedicated PostgreSQL table with explicit foreign keys, cascading deletes, and strict uniqueness guarantees.

```sql
CREATE TABLE user_track_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    track_id UUID NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    CONSTRAINT uq_user_track_likes_user_track UNIQUE (user_id, track_id)
);

-- Indices for rapid lookup and chronological timeline generation
CREATE INDEX ix_user_track_likes_user_id ON user_track_likes (user_id);
CREATE INDEX ix_user_track_likes_track_id ON user_track_likes (track_id);
CREATE INDEX ix_user_track_likes_user_created ON user_track_likes (user_id, created_at DESC);
```

### Denormalized Counter on `tracks`
To avoid expensive `COUNT(*)` queries on popular tracks, public like counts are denormalized onto the `tracks` table:
```sql
ALTER TABLE tracks ADD COLUMN likes_count INTEGER NOT NULL DEFAULT 0;
CREATE INDEX ix_tracks_likes_count ON tracks (likes_count DESC);
```

---

## 2. Idempotency & Concurrency Guarantees

Under high concurrency or rapid multi-tap scenarios, state corruption and counter drift are prevented at the database layer.

### 2.1 Like Track (Idempotent Insertion)
```sql
-- Step 1: Attempt insert with conflict suppression
INSERT INTO user_track_likes (id, user_id, track_id, created_at)
VALUES (:id, :user_id, :track_id, NOW())
ON CONFLICT (user_id, track_id) DO NOTHING
RETURNING id;

-- Step 2: Increment counter ONLY if a new row was actually inserted
UPDATE tracks
SET likes_count = likes_count + 1
WHERE id = :track_id;
```

### 2.2 Unlike Track (Idempotent Deletion)
```sql
-- Step 1: Delete existing relationship and check row count
DELETE FROM user_track_likes
WHERE user_id = :user_id AND track_id = :track_id
RETURNING id;

-- Step 2: Decrement counter with floor protection (never negative)
UPDATE tracks
SET likes_count = GREATEST(0, likes_count - 1)
WHERE id = :track_id;
```

---

## 3. Recommendation Engine Signal Integration

In Hums, a user liking a track represents an explicit, high-confidence expression of musical preference.

The recommendation engine (`UserPreferenceService`) incorporates liked tracks alongside listening history:

```python
# Extract user's liked tracks
liked_tracks = await self._like_repo.get_user_liked_tracks(user_id=user_id, limit=100)

for like in liked_tracks:
    # High positive reinforcement weight
    weight = 3.0
    
    if like.track.genre:
        genre_scores[like.track.genre.lower()] += weight
    if like.track.artist_name:
        artist_scores[like.track.artist_name.lower()] += weight
```

### Relative Affinity Weights
- **Track Stream Completion (>80%)**: `+1.0`
- **Track Repeat Stream**: `+1.5`
- **Track Added to Playlist**: `+2.0`
- **Follow Creator**: `+2.5`
- **Like Track**: `+3.0` (Strongest explicit positive signal)

---

## 4. Anti-Patterns Explicitly Avoided

1. **Likes As Secret Playlists**: No hidden playlists are created in `playlists`. Likes have distinct semantic meaning, separate lifecycle, and dedicated performance indexing.
2. **Client-Driven Counters**: The client never passes new counter values; all metrics are evaluated and committed server-side.
3. **N+1 Status Checks**: The client never performs `GET /tracks/{id}/like-status` in a loop across lists; the backend resolves `is_liked` in batch.
