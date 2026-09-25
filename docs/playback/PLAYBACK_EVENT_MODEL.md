# HUMS — Playback Event Lifecycle & Data Model

## 1. Playback Lifecycle Events

| Event Type | Trigger | Description | Progress Updated |
| :--- | :--- | :--- | :--- |
| `PLAY_STARTED` | Track play initiated | User tapped play on a track, resume point, or queue progression | Yes (resets completion if started at 0) |
| `PROGRESS_CHECKPOINT` | 15s periodic interval | Regular heartbeat during active continuous playback | Yes |
| `PAUSED` | User taps pause | Playback explicitly paused | Yes |
| `RESUMED` | User taps resume | Playback restarted from paused state | No (position unchanged) |
| `SEEKED` | User scrubs track | Scrubbing slider moved to a new timestamp | Yes |
| `SKIPPED` | Next / previous button | Track changed before reaching the completion threshold | Yes |
| `COMPLETED` | Track reaches >= 95% | Track finished listening or crossed completion threshold | Yes (`completed = true`) |
| `STOPPED` | Player stopped / closed | Playback ended or player dismissed | Yes |

---

## 2. Event Payload Schema

```json
{
  "event_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "track_id": "a3b18c72-f109-42ed-9802-ae2c6a935098",
  "event_type": "PROGRESS_CHECKPOINT",
  "position_ms": 45000,
  "duration_ms": 180000,
  "played_at": "2026-09-25T15:45:00.000Z",
  "source": "player",
  "device_id": "iPhone15,2"
}
```

### Field Definitions & Validation Rules
* `event_id` (`UUID`, Required): Universally unique identifier generated on the client via RFC 4122 v4. Used as the database idempotency key.
* `track_id` (`UUID`, Required): Foreign key to target track in the Hums audio catalog.
* `event_type` (`String(50)`, Required): One of the 8 canonical lifecycle event types listed above.
* `position_ms` (`Integer >= 0`, Required): Current playback position in milliseconds. Clamped to `[0, duration_ms]`.
* `duration_ms` (`Integer >= 0`, Required): Total track length in milliseconds.
* `played_at` (`TIMESTAMPTZ`, Required): Client UTC timestamp when the event occurred. Must not be > 1 day in the future or > 2 years in the past.
* `source` (`String(50)`, Default: `'player'`): Source channel (e.g. `'player'`, `'offline_sync'`, `'carplay'`).
* `device_id` (`String(100)`, Optional): Non-sensitive device model identifier for debugging.
