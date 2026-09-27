# Hums Mobile Application

Flutter mobile client for the Hums high-fidelity audio streaming platform.

## Architecture

- **State Management:** Flutter Riverpod (`StateNotifierProvider`, `Provider`, `FutureProvider`)
- **Networking:** Dio with custom `AuthInterceptor`, `LoggingInterceptor`, and typed `ApiException` handling
- **Routing:** GoRouter with reactive auth state redirection and deep linking
- **Design System:** Obsidian acoustic warmth theme (`AppColors`, `AppSpacing`, `AppTypography`, `AppTheme`)
- **Audio Playback:** `just_audio` with `just_audio_background` media notifications
- **Push Notifications:** Firebase Cloud Messaging (`firebase_core`, `firebase_messaging`) with backend registration, background/foreground handling, and deep link routing
- **Widget Previews:** Official Flutter Widget Preview system (`package:flutter/widget_previews.dart`, `@Preview(...)`) located in `lib/previews/`

## Features

1. **Authentication:** Registration, login, JWT token management, automatic refresh token rotation, logout.
2. **Audio Upload & Streaming:** Audio file validation, upload, transcode status tracking, multi-bitrate rendition streaming.
3. **Playlists:** User playlist creation, cover artwork, reordering, adding/removing tracks.
4. **Push Notifications & Inbox:**
   - Multi-device registration on backend (`/api/v1/notifications/devices`).
   - Push preferences management (`/api/v1/notifications/preferences`).
   - Notification history with unread count badge, filtering (All/Unread), and bulk read-all (`/api/v1/notifications`).
   - Deep linking directly to tracks and playlists.
   - Foreground notification listening and in-memory inbox updating.

## Running Previews

Previews can be viewed in VS Code / Android Studio using the IDE Widget Preview gutter icons or via:
```bash
flutter widget-preview start
```

## Running Tests

```bash
flutter test
```
