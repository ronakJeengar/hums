# Asynchronous Notification Fan-Out for Creator Activity

## 1. Fan-Out Pipeline

When a creator releases a new track or public content, notification dispatch is executed strictly outside the FastAPI request-response lifecycle using Celery distributed tasks.

```mermaid
sequenceDiagram
    autonumber
    actor Creator
    participant API as FastAPI Audio Ingestion
    participant Celery as Celery Distributed Task
    participant PG as PostgreSQL (Followers & Preferences)
    participant Push as FCM / APNs PushProvider
    actor Follower

    Creator->>API: Publish Track (status -> READY)
    API->>Celery: fanout_creator_new_release.delay(creator_id, track_id, track_title)
    API-->>Creator: 200 OK (Track Published)

    note over Celery: Asynchronous Background Execution
    Celery->>PG: Query all followers from creator_followers WHERE creator_id = :creator_id
    Celery->>PG: Query notification_preferences for followers
    note over Celery: Filter out users with new_releases_enabled = false

    loop For each eligible follower
        Celery->>Push: PushProvider.send_multicast(title, body, data={type: "new_release", track_id: ...})
        Push-->>Follower: Display System Notification
    end
```

---

## 2. Preference Enforcement & User Privacy

Before dispatching a push notification, the worker queries `notification_preferences` for each follower:
* If `new_releases_enabled == False`, the user is silently omitted from the fan-out batch.
* Stale or invalid device tokens returned by `PushProvider` are automatically deactivated in `user_devices`.
* Rate limiting and batch chunking (default chunk size: 500 followers) prevent worker memory starvation during high-follower artist releases.

---

## 3. Deep Linking & Mobile Handling

Push notifications payload schema:

```json
{
  "title": "New Release from Arijit Singh",
  "body": "Listen to 'Kesariya' now on Hums.",
  "data": {
    "type": "new_release",
    "track_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
    "creator_id": "c7a8b9c0-1234-5678-9abc-def012345678",
    "click_action": "FLUTTER_NOTIFICATION_CLICK"
  }
}
```

When tapped by the user, the Flutter notification handler routes directly to:
* The track in the global audio player: `audioPlayerNotifierProvider.playTrack(trackId)`
* Or the creator profile: `/creators/:id`
