# Media Processing & Renditions UI

## 1. Overview

Hums rejects fabricated, synthetic progress bars in favor of **authoritative processing diagnostics**. Both creators and platform administrators can inspect exact FFmpeg rendition details, Celery worker states, retry counters, and low-level transcoding error logs directly from the UI.

---

## 2. Processing Pipeline Lifecycle

```
[ Upload Complete ] ──► Status: UPLOADED
                              │
                              ▼
                      Status: PROCESSING
                              │
          ┌───────────────────┴───────────────────┐
          ▼                                       ▼
  Transcoding Succeeded                  Transcoding Failed
  Status: READY                          Status: FAILED
  • 128 kbps AAC generated              • Error log captured
  • 192 kbps AAC generated              • Retry counter incremented
  • 320 kbps AAC generated              • UI displays retry button
  • Waveform JSON extracted
```

---

## 3. Real-Time Status Polling

Rather than continuous polling or fake progress simulation, the track detail pages (`/studio/tracks/[id]` and `/admin/tracks/[id]`) employ adaptive polling via TanStack Query:

```ts
refetchInterval: (query) => {
  const status = query.state.data?.status;
  // Poll only while active async work is pending
  return status === "PROCESSING" || status === "UPLOADED" ? 4000 : false;
}
```

When the worker updates the database record to `READY` or `FAILED`, the query stops polling automatically, minimizing network overhead and database CPU consumption.

---

## 4. Transcoded Rendition Breakdown

The renditions table exposes low-level audio engineering specifications:
- **Bitrate Profile**: Target output bitrate (`128 kbps`, `192 kbps`, `320 kbps`).
- **Codec & Container**: `AAC` (Advanced Audio Coding) and `MP3`.
- **Sample Rate**: Formatted in kilohertz (e.g., `44.1 kHz`, `48.0 kHz`).
- **Channels**: Semantic channel detection (`Stereo` vs `Mono`).
- **Exact File Size**: Formatted in megabytes (`MB`).
- **Storage Key**: MinIO/S3 object reference (e.g., `renditions/trk-uuid/192k.aac`).

---

## 5. Diagnostic Error Logs & Manual Retry Triggers

When FFmpeg or Celery encounters an unrecoverable encoding error (e.g., corrupted audio stream, unsupported codec, missing audio track):
1. **Error Recording**: The error trace is persisted to `AudioProcessingJob.error_message`.
2. **Visual Diagnostic**: The UI displays a high-visibility error card containing the exact error trace.
3. **Execution Counter**: The UI displays the number of retry attempts (`attempts`).
4. **Retry Trigger**:
   - Creators can trigger `/api/v1/creator-studio/tracks/{id}/retry`.
   - Admins can trigger `/api/v1/admin/tracks/{id}/retry` or bulk retry.
   - The endpoint resets `Track.status = PROCESSING`, queues a new Celery task, and clears previous execution errors.
