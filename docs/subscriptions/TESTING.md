# Subscriptions & Entitlements Test Suite

## Overview

The Subscriptions & Premium Entitlements feature is verified by an extensive automated test suite covering the FastAPI backend, PostgreSQL database migrations, Redis caching, audio stream gating, and Flutter mobile presentation layers.

---

## 1. Test Summary

| Layer | Test Suite | Tests Run | Result | Coverage Area |
| :--- | :--- | :--- | :--- | :--- |
| **Backend** | `test_subscriptions.py` | 13 | **PASS (13/13)** | Catalog, purchase verification, replay protection, cross-account 409, restore, webhook deduplication, audio fallback, download gating. |
| **Backend Full** | `backend/tests/` | 206 | **PASS (206/206)** | Entire backend regression test suite including auth, playback, playlists, uploads, and search. |
| **Frontend** | `subscription_notifier_test.dart` | 7 | **PASS (7/7)** | Riverpod notifier state transitions, purchase failure handling, restore flow, logout cache wipe. |
| **Frontend** | `premium_plans_screen_test.dart` | 1 | **PASS (1/1)** | Paywall UI, pricing display, plan selection, CTA label updates. |
| **Frontend** | `subscription_status_screen_test.dart` | 2 | **PASS (2/2)** | Free tier state, active premium state, billing dates, entitlements list, management dialog. |
| **Frontend Full** | `mobile/test/` | 290 | **PASS (290/290)** | Complete mobile widget and unit test suite. |
| **Static Analysis**| `flutter analyze` | - | **0 Issues** | Strict lint and type checking across all mobile files. |
| **Database** | Alembic Migration | - | **PASS** | Tested `upgrade head`, `downgrade -1`, and re-upgrade cleanly. |

---

## 2. Key Test Scenarios & Assertions

### A. Replay Protection & Cross-Account Reuse

- **Scenario:** Attacker intercepts a valid purchase token belonging to User A and submits it under User B's authentication session.
- **Assertion:** Backend rejects with `HTTP 409 Conflict` and error code `CROSS_ACCOUNT_REPLAY`. Entitlements are NOT granted to User B.

### B. Same-User Idempotent Retry

- **Scenario:** Flutter app loses network connection immediately after purchase submission and retries the same transaction token for User A.
- **Assertion:** Backend returns `HTTP 200 OK` with the existing active subscription. No duplicate rows created in `user_subscriptions`.

### C. Webhook Deduplication

- **Scenario:** Apple/Google re-delivers the same notification UUID multiple times due to retry policies.
- **Assertion:** First delivery processes successfully (`processed_at` populated). Subsequent deliveries detect the unique constraint `(provider, provider_event_id)`, increment Prometheus metric `webhook_duplicate_events_total`, and return HTTP 200 without redundant state recomputation.

### D. Audio Stream Gating & Deterministic Fallback

- **Scenario:** Free user requests `HIGH` quality (192 kbps) audio stream.
- **Assertion:** Backend checks `EntitlementService.has_entitlement(user_id, "PREMIUM_AUDIO_QUALITY")`. Since entitlement is absent, backend deterministically falls back to `MEDIUM` quality (128 kbps) with `is_fallback=True`, ensuring seamless music playback without crashing or breaking free-tier experience.

### E. Offline Download Protection

- **Scenario:** Free user requests offline download rendition for another creator's track.
- **Assertion:** Backend verifies `can_download_track` and rejects with `HTTP 403 Forbidden`. Track uploaders retain full download rights for their own content.

---

## 3. How to Run Tests

### Run Backend Tests

```bash
cd backend
source .venv/bin/activate

# Run subscription-specific tests
pytest tests/test_subscriptions.py -v

# Run full backend test suite
pytest -v
```

### Run Frontend Mobile Tests

```bash
cd mobile

# Run static analysis
flutter analyze

# Run subscription tests
flutter test test/features/subscriptions/

# Run complete mobile test suite
flutter test
```
