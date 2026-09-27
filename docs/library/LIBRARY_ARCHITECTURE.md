# Personal Library & Favorites Architecture

## 1. System Overview

The **Likes, Favorites & Personal Library** subsystem in Hums provides authenticated users with a low-friction mechanism to save audio content, organize their personal audio library, and feed high-intent preference signals into the recommendation engine.

```mermaid
flowchart TD
    User([Authenticated User]) -->|Tap Like / Unlike| LikeButton[LikeButton Component]
    LikeButton -->|Optimistic State| LikeNotifier[LikeNotifier family]
    LikeNotifier -->|HTTP POST/DELETE| LikeRouter[FastAPI /tracks/{id}/like]
    LikeRouter --> LikeService[LikeService]
    LikeService --> LikeRepo[LikeRepository]
    LikeRepo --> PostgreSQL[(PostgreSQL user_track_likes)]
    LikeService --> Redis[(Redis Cache)]
    LikeService --> RecSignal[Recommendation Preference Signal +3.0]
    
    User -->|View Library| LibraryScreen[LibraryScreen /library]
    LibraryScreen --> LibrarySummaryNotifier[LibrarySummaryNotifier]
    LibrarySummaryNotifier -->|HTTP GET| LibraryRouter[FastAPI /library]
    
    User -->|View Liked Songs| LikedSongsScreen[LikedSongsScreen /liked-songs]
    LikedSongsScreen --> LikedTracksNotifier[LikedTracksNotifier]
    LikedTracksNotifier -->|HTTP GET| LikedTracksRouter[FastAPI /library/liked-tracks]
```

---

## 2. Core Architectural Principles

### 2.1 Distinct Architectural Concepts: Likes vs Playlists
A critical architectural tenet of Hums is that **Likes** and **Playlists** are distinct domains:
1. **Likes (`user_track_likes`)**: Represents an explicit 1:1 user-to-content affinity signal ("I love this song / bookmark for later"). It is modeled as a dedicated relational link table with strict uniqueness and server-managed counters. It is *never* modeled as a synthetic or hidden playlist.
2. **Playlists (`playlists` & `playlist_tracks`)**: Represents an intentional collection created or curated by a user with custom sequencing, titles, descriptions, and cover art.

### 2.2 Server-Authoritative Counters & Idempotent Concurrency
- `tracks.likes_count` is maintained exclusively on the server through transactional PostgreSQL operations.
- The mobile application **never** increments or decrements public counters locally to persist them.
- Idempotent conflict resolution:
  - **Like**: `INSERT INTO user_track_likes ... ON CONFLICT (user_id, track_id) DO NOTHING` combined with conditional counter increment (`likes_count + 1`). Duplicate taps never result in counter drift.
  - **Unlike**: `DELETE FROM user_track_likes WHERE user_id = :u AND track_id = :t RETURNING id` combined with floored counter decrement: `UPDATE tracks SET likes_count = GREATEST(0, likes_count - 1)`.

### 2.3 Elimination of N+1 Network & Database Queries
- Track listings (Search, Recommendations, Creator Profiles, Playlists) expose `is_liked` directly in their response payload.
- Repository layer executes batch resolution (`is_liked_batch`) in a single SQL query:
  ```sql
  SELECT track_id FROM user_track_likes WHERE user_id = :user_id AND track_id = ANY(:track_ids);
  ```
- Mobile components (`LikeButton`) initialize synchronously with `initialLiked` and `initialCount`, strictly avoiding background `GET like-status` calls on mount.

---

## 3. Endpoints & API Contracts

| Method | Endpoint | Description | Auth Required | Cache Invalidation |
|---|---|---|---|---|
| `POST` | `/api/v1/tracks/{track_id}/like` | Like a track (idempotent) | Yes | `like:status:{u}:{t}`, `library:summary:{u}` |
| `DELETE` | `/api/v1/tracks/{track_id}/like` | Unlike a track (idempotent) | Yes | `like:status:{u}:{t}`, `library:summary:{u}` |
| `GET` | `/api/v1/tracks/{track_id}/like-status` | Query like status & count | Yes | Cached in Redis (TTL 300s) |
| `GET` | `/api/v1/library` | Aggregated personal library metrics | Yes | Cached in Redis (TTL 120s) |
| `GET` | `/api/v1/library/liked-tracks` | Paginated list of liked tracks (`liked_at DESC`) | Yes | Dynamic query |

---

## 4. Mobile Architecture (Flutter / Riverpod)

The Flutter mobile implementation follows Clean Architecture under `lib/features/library/`:

```text
mobile/lib/features/library/
├── domain/
│   ├── entities/
│   │   ├── like_status_entity.dart
│   │   ├── liked_track_entity.dart
│   │   └── library_summary_entity.dart
│   └── repositories/
│       └── library_repository.dart
├── data/
│   ├── models/
│   │   ├── like_status_model.dart
│   │   ├── liked_track_model.dart
│   │   └── library_summary_model.dart
│   ├── datasources/
│   │   └── library_remote_data_source.dart
│   └── repositories/
│       └── library_repository_impl.dart
└── presentation/
    ├── states/
    │   └── like_state.dart
    ├── providers/
    │   ├── library_provider.dart
    │   └── like_notifier.dart
    ├── widgets/
    │   └── like_button.dart
    └── screens/
        ├── library_screen.dart
        └── liked_songs_screen.dart
```

### 4.1 State Flow & Optimistic Updates
1. **User interaction**: User taps `LikeButton`.
2. **Animation**: Scale transition executes (0.8x -> 1.0x bounce) for immediate tactile feedback.
3. **Optimistic Mutation**: `LikeNotifier.toggleLike()` immediately flips `isLiked` and adjusts `likesCount` by `±1`.
4. **Network Dispatch**: Sends `POST` or `DELETE` to the backend.
5. **Cross-Provider Invalidation**: On success, `librarySummaryProvider` is invalidated, and if unliking, `likedTracksNotifierProvider.removeTrack(trackId)` removes the song from the liked songs list without requiring a full network refetch.
6. **Automatic Rollback**: If the network request fails, `LikeNotifier` automatically rolls back to the previous state and displays user-friendly error feedback.

### 4.2 Account Isolation
When a user logs out (`AuthNotifier.logout()`), Riverpod providers for `librarySummaryProvider` and `likedTracksNotifierProvider` are explicitly invalidated and wiped to prevent state leakage across sessions.
