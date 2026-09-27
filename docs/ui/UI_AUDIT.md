# Hums Mobile UI Audit: Current State vs. Production Reference

## 1. Executive Summary
This audit reviews the visual and experiential state of the Hums mobile client prior to the revamp and contrasts it directly with the newly established visual baseline derived from the reference design system (located in `mobile/images/`).

The legacy UI suffered from severe visual clutter, lack of typography contrast, flat pitch-black backgrounds with harsh borders, unpolished standard Material 3 controls, an overloaded home app bar (11 separate icon buttons crammed together), inconsistent card padding and radii, and disjointed playback and detail screens.

The revamp replaces this baseline with an obsidian-toned, ambiently lit, pill-accented design system featuring clean hierarchy, elevated card containers, signature overlapping creator badges, refined typography, smooth gesture navigation, and a modern audio player suite.

---

## 2. Granular Screen-by-Screen Audit

| Screen / Area | Pre-Revamp Issues | Revamp Target (Reference Visual Language) |
|---|---|---|
| **App Shell & Theme** | Pitch black (`#000000`), harsh white borders, unharmonized accent colors, standard square-ish Material borders. | Deep obsidian navy (`#0D111A`), elevated slate card surfaces (`#151B26`), subtle 6% opacity light borders, warm coral (`#FF7A59`) & crisp white pill accents. |
| **Welcome / Splash** | Generic center logo with spinner or plain direct route; no onboarding visual impact. | Reference Gateway Screen: Full obsidian canvas, lowercase `hums` logotype with subtitle, crisp white pill "Get Started" CTA, secondary dark pill "Login", minimal footer. |
| **Home Screen** | Cluttered top app bar with 11 icon buttons (search, queue, history, liked, playlists, profile, etc.); disjointed section headers; generic list tiles. | Reference Header: Left unread-dot notification bell, centered `hums` logo, right profile avatar. Hero featured gradient card with play CTA. Horizontal carousels with overlapping circular creator badges. |
| **Global Player (Full)** | Flat dark sheet, small artwork, standard linear progress bar, cramped text, no Up Next pill. | Reference Player: Ambient background glow reflecting track mood, centered creator pill badge, 24px rounded artwork with depth shadow, title + artist with inline favorite heart, sleek scrubber, 64px circular play button, and docked "Up Next" bottom pill drawer. |
| **Mini Player** | Inconsistent dock height, flat black bar, basic text, prone to obscuring bottom nav or content. | Reference Mini Player: Floating 16px rounded slate card hovering cleanly above bottom nav with track artwork, title/artist, play/pause circular button, and smooth tap-to-expand. |
| **Track & Content Detail** | Generic top app bar and plain vertical list. | Reference Detail: Ambient curved color accent header behind hero artwork, tag pills, expandable "...see more" description, large coral "PLAY NOW" pill CTA + secondary action button, clean chapter/tracklist rows with duration and download status. |
| **Search & Discovery** | Plain text field with generic list; raw query suggestions; lack of filter chips. | Reference Search: Elevated search input container with subtle border, category filter pill chips (Tracks, Creators, Playlists, Albums), recent search tags, high-contrast search results. |
| **Library & Liked Songs** | Basic list view with default list tiles and standard FAB. | Reference Library: Tabbed category view (Liked Songs, History, Downloads, Playlists), hero playlist card with track count badge, play all pill CTA, standardized `HumsTrackTile` with swipe actions. |
| **Creator Profiles** | Default banner and unstyled follow button. | Reference Creator: Verified badge, follower metrics, social action row, top releases carousel, following status pill button. |
| **Lyrics & Transcript** | Plain text container without interactive synchronized highlighting. | Reference Lyrics: Large typography with synchronized timing highlight, ambient color gradient, tap-to-seek, smooth auto-scroll. |

---

## 3. Revamp Priorities
- **Priority 1 (Core Navigation & Experience):** Theme system, reusable widget catalog (`HumsButton`, `HumsCard`, `HumsArtwork`, `HumsTrackTile`), `HomeScreen`, `SearchScreen`, `FullPlayerScreen`, `MiniPlayer`.
- **Priority 2 (Authentication & Content Flows):** `SplashScreen` (welcome gateway), `LoginScreen`, `SignupScreen`, `PlaylistDetailScreen`, `CreatorProfileScreen`, `LikedSongsScreen`.
- **Priority 3 (Utility & Settings):** `LibraryScreen`, `LyricsScreen`, `DownloadsScreen`, `ProfileScreen`, `NotificationScreen`.
