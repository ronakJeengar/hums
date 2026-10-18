# Web Audio Upload & Ingestion Workflow

## 1. Overview

The **Hums Web Audio Ingestion Workflow** (`/studio/upload`) enables creators to upload multi-megabyte audio files and optional high-resolution album artwork with real transfer progress tracking, client-side metadata pre-inspection, and immediate asynchronous transcoding orchestration.

---

## 2. Ingestion Pipeline Architecture

```
[ Browser / Next.js ]
      │
      ├── 1. Client-Side Validation (Audio format, MIME check, duration probe)
      │
      ├── 2. Direct Multipart POST (/api/v1/audio/upload)
      │      └── Real XHR upload.onprogress (0% -> 100% byte counter)
      │
      ▼
[ FastAPI Backend ]
      │
      ├── 3. Magic Byte & MIME Inspection (mutagen / libmagic)
      ├── 4. AudioFile & Track Entity Creation (status = UPLOADED)
      ├── 5. Stream Raw File to Object Storage (MinIO / S3)
      │
      ├── 6. Artwork Ingestion (Optional JPEG/PNG/WebP upload & thumbnail)
      │
      ▼
[ Celery / Redis Task Queue ]
      │
      └── 7. Dispatch transcode_audio_task(track_id)
             ├── Probe audio with ffprobe
             ├── Extract waveform JSON
             ├── Generate multi-bitrate AAC (128kbps, 192kbps, 320kbps)
             ├── Generate fallback MP3
             └── Set Track.status = READY
```

---

## 3. Real XHR Progress Tracking (No Fake Bars)

Unlike synthetic progress bars that increment on artificial timers, the Hums web client utilizes native `XMLHttpRequest` via `api.studio.uploadTrack`:

```ts
const xhr = new XMLHttpRequest();
xhr.upload.onprogress = (event) => {
  if (event.lengthComputable) {
    const percent = Math.round((event.loaded / event.total) * 100);
    onProgress?.({
      percent,
      loadedBytes: event.loaded,
      totalBytes: event.total,
    });
  }
};
```

This guarantees:
- The progress indicator reflects physical TCP/IP socket buffer flushes.
- Once the byte transfer hits 100%, the UI transitions to "Server processing & persisting" while awaiting backend validation and MinIO storage commits.

---

## 4. Metadata Validation & Client Probing

Prior to network transfer, the browser inspects the audio file:
- **Audio Context Probing**: An `Audio` element parses the local `blob:` URL to extract duration in seconds and sample rate.
- **Allowed Audio Formats**: `audio/mpeg` (`.mp3`), `audio/wav` (`.wav`), `audio/flac` (`.flac`), `audio/aac` (`.aac`), `audio/ogg` (`.ogg`). Maximum file size: 150 MB.
- **Metadata Fields**:
  - `title` (required, 1-255 characters).
  - `artist_name` (optional, falls back to creator's verified stage name).
  - `album_name` (optional).
  - `genre` (selected from standardized catalog).
  - `description` (optional liner notes).
  - `is_published` (defaults to draft mode until transcode completes).

---

## 5. Post-Upload Processing Timeline

Immediately following upload confirmation, the creator is presented with a real-time status monitor:
1. **Upload Received**: Audio file stored in object storage.
2. **Audio Inspection**: Format verification and bit depth detection.
3. **Multi-Bitrate Transcoding**: Running Celery worker tasks.
4. **Platform Availability**: Direct link to edit metadata or view playback readiness.
