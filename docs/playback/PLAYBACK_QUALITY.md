# Playback Quality Architecture & Specifications

## Overview

Hums features a production-grade audio pipeline that provides users with fine-grained control over audio fidelity, streaming bandwidth, and offline storage. The audio pipeline is driven by real server-side transcoding ladders produced via FFmpeg, with strict enforcement against synthetic or non-existent bitrates.

---

## Audio Transcode Ladder

Audio uploaded to Hums is transcoded into AAC (Advanced Audio Coding) within an M4A (MPEG-4 Part 14) container across three distinct fidelity tiers:

| Quality Tier | Target Bitrate | Codec / Container | Average Size / Min | Typical Listening Profile |
| :--- | :--- | :--- | :--- | :--- |
| **HIGH** | `192 kbps` | AAC / M4A | `~1.5 MB/min` | Audiophile, Hi-Fi headphones, Wi-Fi / unmetered connections |
| **MEDIUM** | `128 kbps` | AAC / M4A | `~1.0 MB/min` | Standard listening, mobile data, balanced performance |
| **LOW** | `64 kbps` | AAC / M4A | `~0.5 MB/min` | Data saver mode, constrained cellular connections, low storage |

> **Note on Non-Existent Bitrates**:
> Hums does not expose fake or interpolated `320 kbps` or lossless tiers when the underlying transcoding infrastructure produces 192k/128k/64k AAC renditions. Quality tiers reflect real transcode assets with verifiable byte sizes and bitrates.

---

## Architecture

```
                  ┌────────────────────────────────────────────────────────┐
                  │                    Flutter Client                      │
                  │                                                        │
                  │  ┌────────────────────────┐  ┌──────────────────────┐  │
                  │  │ PlaybackSettingsStore  │  │ NetworkInfoService   │  │
                  │  │ (Local Secure Storage) │  │ (Wi-Fi / Cell / Off) │  │
                  │  └───────────┬────────────┘  └──────────┬───────────┘  │
                  │              │                          │              │
                  │              ▼                          ▼              │
                  │     ┌────────────────────────────────────────┐         │
                  │     │       PlaybackQualityResolver          │         │
                  │     └───────────────────┬────────────────────┘         │
                  │                         │                              │
                  │       Resolved Quality  │ (e.g. HIGH, MEDIUM, LOW)     │
                  │                         ▼                              │
                  │     ┌────────────────────────────────────────┐         │
                  │     │           AudioPlayerNotifier          │         │
                  │     └───────────────────┬────────────────────┘         │
                  └─────────────────────────┼──────────────────────────────┘
                                            │ HTTP GET /tracks/{id}/playback?quality={tier}
                                            ▼
                  ┌────────────────────────────────────────────────────────┐
                  │                     FastAPI Backend                    │
                  │                                                        │
                  │  ┌────────────────────────┐  ┌──────────────────────┐  │
                  │  │  audio_service.py      │  │  MetricsCollector    │  │
                  │  │  (Rendition Resolver)  │  │  (Prometheus / Obs)  │  │
                  │  └───────────┬────────────┘  └──────────────────────┘  │
                  │              │                                         │
                  │              ▼                                         │
                  │     ┌────────────────────────────────────────┐         │
                  │     │  Database / S3 Storage Signed URLs     │         │
                  │     │  (Returns requested or fallback URL)   │         │
                  │     └────────────────────────────────────────┘         │
                  └────────────────────────────────────────────────────────┘
```

---

## Backend Endpoints

### 1. User Playback Settings
* **`GET /api/v1/settings/playback`**
  * Fetches the user's persisted audio preferences.
  * Response:
    ```json
    {
      "preferred_streaming_quality": "AUTO",
      "preferred_mobile_quality": "MEDIUM",
      "preferred_wifi_quality": "HIGH",
      "preferred_download_quality": "HIGH",
      "data_saver_enabled": false
    }
    ```
* **`PUT /api/v1/settings/playback`**
  * Updates user audio preferences. Validates tiers (`AUTO`, `LOW`, `MEDIUM`, `HIGH`).

### 2. Audio Playback Authorization
* **`GET /api/v1/audio/tracks/{track_id}/playback?quality={AUTO|LOW|MEDIUM|HIGH}`**
  * Evaluates track renditions and resolves to the best match.
  * Injects `quality` on playback source and lists `available_renditions`:
    ```json
    {
      "source": {
        "url": "https://cdn.hums.app/renditions/track_1_high.m4a",
        "format": "m4a",
        "bitrate_kbps": 192,
        "quality": "HIGH",
        "expires_at": "2026-09-30T23:00:00Z"
      },
      "available_renditions": [
        {"quality": "HIGH", "bitrate_kbps": 192, "format": "m4a"},
        {"quality": "MEDIUM", "bitrate_kbps": 128, "format": "m4a"},
        {"quality": "LOW", "bitrate_kbps": 64, "format": "m4a"}
      ]
    }
    ```

### 3. Track Download Authorization
* **`GET /api/v1/audio/tracks/{track_id}/download?quality={LOW|MEDIUM|HIGH}`**
  * Generates signed CDN download URL for the target offline rendition.
