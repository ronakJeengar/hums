# Webhooks and State Reconciliation

## Overview

Because in-app subscriptions renew, cancel, enter grace periods, or get refunded asynchronously outside the user's active app session, Hums integrates **Server-to-Server Notifications (Webhooks)** from Apple App Store and Google Play.

To guarantee financial consistency and prevent duplicate processing, all webhook events undergo **cryptographic signature verification**, **idempotent deduplication**, and **atomic state reconciliation**.

```mermaid
flowchart TD
    Store[Apple / Google Store] -->|Signed Webhook Event| Ingress[POST /api/v1/webhooks/subscriptions/{provider}]
    Ingress --> SigCheck{Verify Signature?}
    SigCheck -- No --> Reject401[401 Unauthorized]
    SigCheck -- Yes --> DedupCheck{Event ID in DB?}
    DedupCheck -- Yes (Duplicate) --> Fast200[Increment Metric & Return 200 OK]
    DedupCheck -- No (New) --> RecordEvent[Insert into subscription_webhook_events]
    RecordEvent --> ResolveSub[Resolve UserSubscription by provider_subscription_id]
    ResolveSub --> UpdateState[Update Status: ACTIVE / IN_GRACE_PERIOD / CANCELED / EXPIRED / REVOKED]
    UpdateState --> RefreshGrants[Recalculate UserEntitlementGrants]
    RefreshGrants --> EvictCache[Invalidate Redis: entitlements:user:{user_id}]
    EvictCache --> MarkProcessed[Mark processed_at in DB]
    MarkProcessed --> Done200[Return 200 OK]
```

---

## 1. Webhook Endpoint Specification

- **Path:** `POST /api/v1/webhooks/subscriptions/{provider}`
- **Supported Providers:** `apple`, `google`, `mock`
- **Security:**
  - Rate limited to prevent denial-of-service.
  - Payloads must contain valid cryptographic signature or secret headers (`X-Apple-Signature`, `X-Google-Signature`).

---

## 2. Event Deduplication Architecture

Apple and Google guarantee *at-least-once* delivery for server notifications. Network retries frequently deliver the same notification multiple times.

### Persistence Strategy
Every received notification is tracked in PostgreSQL via `subscription_webhook_events`:

| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `UUID` | Primary key |
| `provider` | `String(32)` | `apple` or `google` |
| `provider_event_id` | `String(255)` | Unique event identifier assigned by provider (e.g. `notificationUUID`) |
| `event_type` | `String(64)` | Normalized lifecycle event type |
| `payload` | `JSONB` | Full webhook JSON payload for auditing |
| `processed_at` | `DateTime` | Timestamp of successful processing |
| `error_message` | `Text` | Failure description if processing threw an unhandled exception |

### Unique Constraint
```sql
CONSTRAINT uq_sub_webhook_event UNIQUE (provider, provider_event_id);
```

When a duplicate notification arrives:
1. The repository attempts lookup or atomic insertion.
2. If already present, the service logs an audit message, increments the Prometheus counter `webhook_duplicate_events_total`, and immediately returns HTTP 200 OK.
3. Upstream store servers are notified of delivery success without executing redundant database updates or cache flushes.

---

## 3. Supported Event Types & State Machine

| Provider Event | Normalized Action | Target Subscription Status | Active Entitlements Granted? |
| :--- | :--- | :--- | :--- |
| **Apple `SUBSCRIBED` / Google `PURCHASED`** | Initial activation | `ACTIVE` | **YES** |
| **Apple `DID_RENEW` / Google `RENEWED`** | Period extension | `ACTIVE` | **YES** |
| **Apple `DID_CHANGE_RENEWAL_STATUS` (OFF)** | Auto-renew disabled | `ACTIVE` (`cancel_at_period_end = True`) | **YES** (until period ends) |
| **Apple `DID_FAIL_TO_RENEW` (Grace)** | Billing retry window | `IN_GRACE_PERIOD` | **YES** (during grace period) |
| **Apple `EXPIRED` / Google `EXPIRED`** | Subscription ended | `EXPIRED` | **NO** |
| **Apple `REVOKE` / Google `REVOKED`** | Chargeback / Refund | `REVOKED` | **NO** (immediate revocation) |

---

## 4. Authoritative Request-Time Evaluation vs. Reconciliation

### Request-Time Expiry (First Line of Defense)
Access is never granted based on an unverified database flag.
Every time `EntitlementService.has_entitlement(user_id, code)` executes:
1. It verifies `grant.expires_at >= datetime.now(timezone.utc)`.
2. It verifies `grant.is_revoked is False`.
3. If the subscription's grace period and end date have elapsed, the entitlement is denied immediately, even if a webhook has been delayed or dropped by network partitions.

### Periodic Celery Reconciliation (Second Line of Defense)
A scheduled Celery task runs every 4 hours (`app.tasks.subscriptions.reconcile_subscriptions`):
- Sweeps for subscriptions whose `current_period_end` is in the past and status is still `ACTIVE`.
- Transitions them to `EXPIRED` or checks store APIs for missed renewal webhooks.
- Flushes Redis caches to ensure consistency across edge nodes.
- Dispatches push notifications alerting users to update billing information if within billing retry.

---

## 5. Metrics and Observability

The following metrics are exposed on `/metrics`:

- `webhook_events_received_total{provider, event_type}`: Total incoming webhooks.
- `webhook_duplicate_events_total{provider}`: Count of successfully deduplicated replay events.
- `subscription_verifications_total{provider, status}`: Verifications partitioned by success / failure.
- `entitlement_denials_total{entitlement_code, reason}`: Denied feature attempts.
