# Data Saver Mode

## Overview

Data Saver mode is designed for bandwidth-constrained, metered, or mobile data environments. When activated, it drastically curtails cellular network consumption by prioritizing lower bitrate renditions without disrupting playback continuity.

---

## Behavior & Specifications

### 1. Cellular Network Enforcement
* When **Data Saver** is enabled (`data_saver_enabled = true`):
  * On **Mobile / Cellular Data** (`NetworkType.mobile`): Audio playback is forced to **LOW** (`64 kbps AAC`).
  * On **Wi-Fi** (`NetworkType.wifi`): Audio playback preserves high-fidelity streaming according to the user's Wi-Fi preferences (`HIGH` by default, or user-selected `MEDIUM` / `HIGH`).
* Bandwidth reduction comparison:
  * Standard High Quality (192 kbps): `~1.5 MB/min` (`~90 MB/hour`)
  * Data Saver Low Quality (64 kbps): `~0.5 MB/min` (`~30 MB/hour`)
  * **Net Savings**: **66.7% data reduction** on cellular connections.

---

### 2. Network Transitions (Adaptive Routing)

The mobile client monitors network interface changes via `NetworkInfoService`:
* **Wi-Fi to Mobile Transition**:
  * If Data Saver is active, future track requests automatically downshift to 64 kbps.
  * If manual override is active for the current track, it takes precedence until the user selects `AUTO` or switches tracks.
* **Mobile to Wi-Fi Transition**:
  * Playback automatically upscales to the configured Wi-Fi quality tier (`HIGH`).

---

### 3. Settings Synchronization & Zero Startup Lag

* The user's Data Saver preference is persisted to the backend database (`users.data_saver_enabled`).
* The mobile application mirrors the setting locally in `FlutterSecureStorage` (`playback_settings_cache`).
* **Zero Startup Latency**:
  * Upon application launch, playback starts immediately using the locally cached preferences without awaiting a network round-trip.
  * An asynchronous background refresh updates the local cache if remote settings changed on another device.
