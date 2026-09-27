# Creator Profiles & Content Aggregates

## 1. Public Creator Data Model

Creator entities in **Hums** isolate public artist metadata from private user accounts:

```text
Creator Public Fields:
├── id (UUID)
├── user_id (UUID, optional link to platform user)
├── name (VARCHAR(150), required)
├── username (VARCHAR(60), unique slug)
├── bio (TEXT, artist biography)
├── avatar_url (TEXT, CDN image URI)
├── cover_image_url (TEXT, high-resolution header image)
├── is_verified (BOOLEAN, blue checkmark indicator)
├── followers_count (INTEGER, server-side counter)
└── created_at (TIMESTAMPTZ)
```

### Strict Privacy Guarantee
Private account attributes (email addresses, phone numbers, password hashes, payment records, listening history, device identifiers) are strictly omitted from creator models and serializers.

---

## 2. Content Aggregation Architecture

When loading a creator profile (`GET /api/v1/creators/{creator_id}`), the repository aggregates discography elements in parallel without generating N+1 queries:

```text
CreatorDetailResponse
├── id, name, username, bio, avatar_url, cover_image_url, is_verified, followers_count
├── is_following (resolved for current authenticated user or null)
├── popular_tracks: Top 10 tracks by play count (or recent if counts equal)
├── latest_tracks: 10 most recently published READY tracks
├── albums: Unique album groupings with calculated track counts
└── playlists: Public curated playlists owned by the creator
```

### Query Execution Optimization
* Tracks are filtered by `status = 'READY'`.
* Albums are grouped via `SELECT album_name, COUNT(id) FROM tracks WHERE status = 'READY' AND ... GROUP BY album_name`.
* Playlists are filtered by `is_public = true AND owner_id = :creator_user_id`.

---

## 3. Flutter Presentation Layer

### Visual Layout
The `CreatorProfileScreen` implements a sliver-based scroll architecture:
1. **Collapsible Header (`SliverAppBar`):**
   - High-resolution cover artwork with directional gradient fade.
   - Pinned back button for intuitive navigation.
2. **Identity Section (`SliverToBoxAdapter`):**
   - Circular artist avatar overlapping the cover header.
   - Display name with verified badge.
   - Unique `@username` handle.
   - Reactive follower count formatted dynamically (`1.2M followers`, `450K followers`, `1 follower`).
   - Multi-line artist biography.
   - Embedded `FollowButton` supporting standard and compact variants.
3. **Popular Tracks Section:**
   - Numbered track list with title, album/genre subtitle, and formatted duration (`mm:ss`).
   - Tapping any track instantly triggers global audio playback with queue construction and starting index.
4. **Discography Cards (Albums & Playlists):**
   - Horizontal carousels with artwork, track count badges, and tap navigation.
5. **Persistent Player Overlay:**
   - Embedded `MiniPlayer` floating above the bottom navigation area for uninterrupted listening.
