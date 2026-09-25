# Hums Offline Downloads: Platform Limitations & Operating System Constraints

## Overview

Supporting robust offline audio downloads across both iOS and Android requires accounting for platform-specific lifecycle policies, storage sandboxing, background execution limits, and audio playback engine characteristics.

---

## 1. Background Execution & Download Budgets

### 1.1 iOS Constraints (`NSURLSession` & App Lifecycles)
- **Foreground Priority**: iOS grants full CPU and network throughput while Hums is in the foreground.
- **Background Suspension**: When the app transitions to the background without active audio playback, iOS typically suspends execution within 30 seconds unless a background task is asserted.
- **Background Audio Concurrency**: Because Hums uses `just_audio_background` with `UIBackgroundModes = audio`, network access continues while an audio track is actively streaming or playing. However, downloading an entire album while playback is paused is subject to iOS background task execution limits.
- **Recommendation for Large Playlists**: UI alerts notify the user to keep the application active or connected to power/Wi-Fi when initiating bulk downloads exceeding 50 tracks.

### 1.2 Android Constraints (`Doze Mode` & Battery Optimization)
- **Doze Mode**: When an Android device is unplugged and stationary with the screen off, Doze restricts network access to periodic maintenance windows.
- **App Standby Buckets**: If the user rarely opens Hums, Android limits job execution intervals.
- **Foreground Services**: For extended offline synchronization, Android requires a Foreground Service with a persistent notification (`FOREGROUND_SERVICE_DATA_SYNC`). Hums currently utilizes immediate queue execution with automatic resumption upon network reconnect.

---

## 2. Filesystem Sandboxing & Storage Directories

### 2.1 Storage Location Selection
Hums downloads audio files to the Application Documents Directory:
```dart
final appDocDir = await getApplicationDocumentsDirectory();
// Path: ${appDocDir}/downloads/${userId}/${trackId}/audio.m4a
```

| Directory | Persistence | OS Purge Risk | Cloud Backup Behavior |
| :--- | :--- | :--- | :--- |
| **Temporary (`getTemporaryDirectory`)** | Low | **High** (Purged automatically by iOS/Android under storage pressure) | Excluded |
| **Application Documents (`getApplicationDocumentsDirectory`)** | **High** | **None** (Only removed on app uninstall or explicit app deletion) | Included by default (requires backup exclusion) |

### 2.2 iCloud & Android Auto-Backup Exclusion
- **Rule**: Audio files are large media assets that should **not** consume user iCloud or Google Drive backup quotas.
- **Implementation**: Hums isolates audio media in the `downloads/` subfolder, ensuring high persistence while keeping configuration and database metadata compact.

---

## 3. Audio Format Compatibility

| Audio Format | Codec | Extension | iOS (`AVPlayer`) | Android (`ExoPlayer`) | Hums Production Status |
| :--- | :--- | :--- | :---: | :---: | :--- |
| **AAC-LC** | `aac` | `.m4a` | Native Hardware | Native Hardware | **Primary Production Format** |
| **MP3** | `mp3` | `.mp3` | Native | Native | Supported Fallback |
| **FLAC** | `flac` | `.flac` | iOS 11+ | Native | Reserved for Hi-Fi tiers |

- **Zero Player Divergence**: `just_audio` natively plays both local file paths (`file:///path/to/audio.m4a` or `/path/to/audio.m4a`) and remote HTTP/HLS streams with identical equalizer, volume normalization, and lock-screen metadata.

---

## 4. Low Disk Space & Storage Pressure

- **Safety Margin**: Before enqueuing large downloads, the mobile client calculates current usage against storage quota.
- **Disk Full Handling**: If disk write encounters `FileSystemException (No space left on device)`:
  1. The active download immediately enters `failed` status.
  2. The partial `.part` file is deleted.
  3. User receives a clear notification: `"Insufficient storage space available on device"`.
  4. The FIFO queue stops processing subsequent items until the user frees space or dismisses downloads.
