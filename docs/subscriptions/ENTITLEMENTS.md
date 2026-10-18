# Hums Entitlements & Access Control

**Version:** 1.0.0  
**Status:** Active  
**Author:** Principal Software Architect & Security Engineer  
**Date:** 2026-10-14  

---

## 1. Supported Entitlements

Hums defines three core platform entitlements, strictly mapped to existing functionality in the codebase:

| Entitlement Code | Display Name | Functional Capability Controlled | Free Tier Behavior |
| :--- | :--- | :--- | :--- |
| `PREMIUM_AUDIO_QUALITY` | High Fidelity Audio | Grants access to the `HIGH` (192 kbps AAC) audio transcode rendition for streaming and download. | Requests for `HIGH` stream automatically fallback to `MEDIUM` (128 kbps). Playback never fails. |
| `OFFLINE_DOWNLOADS` | Offline Playback | Grants permission to download tracks to local device storage via `GET /api/v1/audio/tracks/{id}/download`. | Download requests return HTTP 403 Forbidden with `OFFLINE_DOWNLOAD_REQUIRED` code. |
| `UNLIMITED_DOWNLOADS` | Unlimited Downloads | Permits unlimited simultaneous offline downloads without account quota throttling. | Bound to Premium plans. |

---

## 2. Entitlement Evaluation Lifecycle

Entitlements are evaluated dynamically at request time by `EntitlementService`:

```
User Request
     │
     ▼
Check Redis Cache: "entitlements:user:{user_id}"
     │
     ├── Cache Hit: Return cached active codes (TTL = 300s)
     │
     └── Cache Miss:
          │
          ▼
     Query DB:
     1. Fetch active UserSubscriptions where:
        - status IN ('ACTIVE', 'IN_GRACE_PERIOD', 'CANCELED')
        - current_period_end > now() OR grace_period_end > now()
     2. Collect associated PlanEntitlements.
     3. Fetch direct UserEntitlementGrants where:
        - is_active = TRUE
        - effective_start <= now()
        - (effective_end IS NULL OR effective_end > now())
        - revoked_at IS NULL
     4. Merge unique entitlement codes.
     5. Store in Redis with TTL 300s.
     6. Return active codes.
```

---

## 3. Cache Invalidation & Event Triggers

Redis cache entries are invalidated immediately (`await redis.delete(cache_key)`) upon any of the following events:
- Successful purchase verification (`POST /api/v1/subscriptions/verify-purchase`)
- Purchase restore execution (`POST /api/v1/subscriptions/restore`)
- Provider webhook events (cancellation, refund, expiration, renewal)
- Administrative grant or revocation of entitlements
- User account status change

Even in the event of cache desynchronization, the maximum window of stale authorization is bounded by the 300-second TTL.
