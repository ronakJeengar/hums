# Hums Mobile Application

Standalone, high-fidelity audio and podcast streaming application built with Flutter, Riverpod, and Clean Architecture.

---

## Flutter Widget Preview System

Hums includes a centralized, zero-backend Flutter Widget Preview system that allows developers to preview every screen and UI state in realistic smartphone dimensions directly inside IDE previewers (VS Code, Android Studio) or via Flutter tooling.

### Key Capabilities

- **Zero-Backend Dependency**: Previews do not require the FastAPI backend, PostgreSQL, Redis, or Celery.
- **No Real Authentication**: Deterministic mock sessions and guest modes are pre-configured.
- **Isolated Routing**: Embedded `GoRouter` prevents navigation crashes when buttons or cards are clicked in previews.
- **Phone Aspect Ratios**: Realistic smartphone viewports (`PreviewDevices.phoneStandard`, `phoneSmall`, `phoneLarge`).
- **Comprehensive UI States**: Populated, Empty, Loading, Error, Playing, Paused, Light theme, and Dark theme.

---

## Running Widget Previews

### In the IDE (VS Code / Android Studio)

1. Open any preview file in `lib/previews/` (e.g., `lib/previews/home_previews.dart`).
2. Click the **Preview** gutter icon or CodeLens above any `@Preview(...)` annotation.
3. The Flutter Widget Previewer pane opens with the screen rendered at phone dimensions.

### Via Command-Line Tooling

To launch the Flutter Widget Preview server:

```bash
cd mobile
flutter widget-preview start
```

---

## Directory Structure

All preview infrastructure and declarations are cleanly isolated from production code in `lib/previews/`:

```text
mobile/lib/previews/
├── preview_devices.dart     # Standard modern smartphone dimensions
├── preview_data.dart        # Deterministic domain entities & fixture data
├── preview_fakes.dart       # Mock repositories & state notifiers
├── preview_wrapper.dart     # Central previewApp wrapper & default Riverpod overrides
├── auth_previews.dart       # Login, Signup, Forgot Password, Reset Password
├── home_previews.dart       # Home (Populated, Loading, Guest, Light, Small, Large)
├── player_previews.dart     # Full Player (Playing, Paused, Buffering, Idle, Error) & Mini Player
├── audio_previews.dart      # My Uploads (Populated, Empty, Loading) & Audio Upload form states
├── playlist_previews.dart   # Playlists (List, Detail, Create, Edit, Modals)
├── profile_previews.dart    # Profile (Populated, Initials, Loading, Error) & Edit Profile
├── common_previews.dart     # Splash & Error screens
└── screen_previews.dart     # Central index exporting all previews
```

---

## Device Profiles

Standard phone profiles are defined in `mobile/lib/previews/preview_devices.dart`:

| Profile | Dimensions | Aspect Ratio | Target Devices |
| :--- | :--- | :--- | :--- |
| `phoneStandard` | `393 × 852` | ~19.5:9 | iPhone 15/16, Google Pixel 8 |
| `phoneSmall` | `360 × 780` | ~19.5:9 | Compact Android, iPhone 13 mini |
| `phoneLarge` | `430 × 932` | ~19.5:9 | iPhone 15/16 Pro Max, Pixel 8 Pro |

---

## How to Add a Preview for a New Screen

To add a preview for any new screen:

1. Import `package:flutter/widget_previews.dart` and `preview_wrapper.dart`.
2. Define a public top-level function annotated with `@Preview`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:hums_mobile/previews/preview_devices.dart';
import 'package:hums_mobile/previews/preview_wrapper.dart';
import 'package:hums_mobile/features/my_feature/presentation/screens/my_screen.dart';

@Preview(
  group: 'My Feature',
  name: 'My Screen - Populated',
  size: PreviewDevices.phoneStandard,
)
Widget myScreenPopulatedPreview() {
  return previewApp(
    child: const MyScreen(),
  );
}
```

3. To simulate custom states (e.g., error, loading, empty), pass specific Riverpod overrides:

```dart
@Preview(
  group: 'My Feature',
  name: 'My Screen - Error State',
  size: PreviewDevices.phoneStandard,
)
Widget myScreenErrorPreview() {
  return previewApp(
    overrides: [
      myStateProvider.overrideWith(
        (ref) => MyState.error('Failed to load item'),
      ),
    ],
    child: const MyScreen(),
  );
}
```

4. Export your new preview in `mobile/lib/previews/screen_previews.dart`.

---

## Preview Coverage Matrix

| Feature | Screen / Widget | Preview Name | State Represented |
| :--- | :--- | :--- | :--- |
| **Auth** | `LoginScreen` | `loginPreview` | Default idle form |
| **Auth** | `LoginScreen` | `loginErrorPreview` | Failed credentials banner |
| **Auth** | `SignupScreen` | `signupPreview` | Registration form |
| **Auth** | `ForgotPasswordScreen` | `forgotPasswordPreview` | Password reset request |
| **Auth** | `ResetPasswordScreen` | `resetPasswordPreview` | Password token & confirmation |
| **Home** | `HomeScreen` | `homePopulatedPreview` | Authenticated user & healthy backend |
| **Home** | `HomeScreen` | `homeLoadingPreview` | Async health check pending |
| **Home** | `HomeScreen` | `homeGuestPreview` | Unauthenticated / guest state |
| **Home** | `HomeScreen` | `homeLightPreview` | Light theme variant |
| **Home** | `HomeScreen` | `homeSmallPreview` | Compact smartphone viewport |
| **Home** | `HomeScreen` | `homeLargePreview` | Large flagship viewport |
| **Player** | `FullPlayerScreen` | `fullPlayerPlayingPreview` | Active playback with waveform & timer |
| **Player** | `FullPlayerScreen` | `fullPlayerPausedPreview` | Paused playback |
| **Player** | `FullPlayerScreen` | `fullPlayerBufferingPreview` | Buffering spinner |
| **Player** | `FullPlayerScreen` | `fullPlayerIdlePreview` | Idle / no track loaded |
| **Player** | `FullPlayerScreen` | `fullPlayerErrorPreview` | Network playback error |
| **Player** | `MiniPlayer` | `miniPlayerPlayingPreview` | Floating bar (playing) |
| **Player** | `MiniPlayer` | `miniPlayerPausedPreview` | Floating bar (paused) |
| **Audio** | `UserTracksScreen` | `userTracksPopulatedPreview` | Uploaded tracks list |
| **Audio** | `UserTracksScreen` | `userTracksEmptyPreview` | Empty list call-to-action |
| **Audio** | `UserTracksScreen` | `userTracksLoadingPreview` | Loading skeleton |
| **Audio** | `UploadAudioScreen` | `uploadAudioInitialPreview` | Initial file picker form |
| **Audio** | `UploadAudioScreen` | `uploadAudioFileSelectedPreview` | Audio file chosen (metadata ready) |
| **Audio** | `UploadAudioScreen` | `uploadAudioUploadingPreview` | Active upload (45% progress) |
| **Audio** | `UploadAudioScreen` | `uploadAudioFailurePreview` | Upload timeout error |
| **Playlists** | `PlaylistListScreen` | `playlistListPopulatedPreview` | Multiple user playlists |
| **Playlists** | `PlaylistListScreen` | `playlistListEmptyPreview` | Zero playlists empty state |
| **Playlists** | `PlaylistListScreen` | `playlistListLoadingPreview` | Loading indicator |
| **Playlists** | `PlaylistDetailScreen` | `playlistDetailPopulatedPreview` | Playlist tracks with duration & metadata |
| **Playlists** | `PlaylistDetailScreen` | `playlistDetailEmptyPreview` | Empty playlist |
| **Playlists** | `PlaylistDetailScreen` | `playlistDetailLoadingPreview` | Playlist loading |
| **Playlists** | `CreatePlaylistScreen` | `createPlaylistPreview` | Create playlist form |
| **Playlists** | `EditPlaylistScreen` | `editPlaylistPreview` | Edit existing playlist details |
| **Playlists** | `SelectTrackModal` | `selectTrackModalPreview` | Track selector sheet |
| **Playlists** | `AddToPlaylistModal` | `addToPlaylistModalPreview` | Playlist picker sheet |
| **Profile** | `ProfileScreen` | `profileLoadedPreview` | Profile with avatar image |
| **Profile** | `ProfileScreen` | `profileInitialsPreview` | Profile with monogram initials |
| **Profile** | `ProfileScreen` | `profileLoadingPreview` | Profile loading |
| **Profile** | `ProfileScreen` | `profileErrorPreview` | Profile error with retry button |
| **Profile** | `EditProfileScreen` | `editProfilePreview` | Edit profile form |
| **Common** | `SplashScreen` | `splashPreview` | App logo & initialization splash |
| **Common** | `ErrorScreen` | `errorDefaultPreview` | Generic 404 / 500 error screen |
| **Common** | `ErrorScreen` | `errorCustomPreview` | Specific error explanation |

---

## Troubleshooting Tips

- **Navigation inside Previews**: `previewApp` sets up a catch-all `GoRouter` (`/` and `/:any*`). Navigation actions like `context.push(...)` or `context.go(...)` will safely update routes without throwing unhandled exceptions.
- **Provider Missing Overrides**: If a new screen depends on an unregistered Riverpod provider, add its mock or initial state to `defaultPreviewOverrides` in `lib/previews/preview_wrapper.dart` so all previews automatically inherit it.
- **Image Network Errors**: For widget tests and offline previews, prefer using `profileInitialsPreview` or deterministic assets rather than remote HTTP images, as test runners block live HTTP requests.
