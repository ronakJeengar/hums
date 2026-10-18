# Pull Request: Subscriptions & Premium Entitlements

- **Source Branch:** `feature/subscriptions-premium`
- **Target Branch:** `main`
- **PR URL:** [Open Pull Request](https://github.com/ronakJeengar/hums/pull/new/feature/subscriptions-premium)

---

## Summary of Changes

This pull request introduces a production-grade, server-authoritative **Subscriptions & Premium Entitlements** system across both the FastAPI backend and Flutter mobile application for Hums.

### Key Highlights

1. **Database & Migrations (`backend/app/db/models/subscription.py`, Alembic):**
   - Tables: `subscription_plans`, `entitlements`, `plan_entitlements`, `user_subscriptions`, `user_entitlement_grants`, `subscription_transactions`, `subscription_webhook_events`.
   - Migration `20260929_d0e123456789_create_subscription_and_entitlement_tables.py` tested with clean upgrades and downgrades.
   - Seeded default catalog: `FREE`, `PREMIUM_MONTHLY` ($9.99/mo), `PREMIUM_YEARLY` ($99.99/yr).

2. **Server-Authoritative Purchase Verification (`backend/app/services/billing/`):**
   - Pluggable provider architecture: Apple StoreKit 2 / App Store Server API, Google Play Developer API (`purchases.subscriptionsv2`), and `MockBillingProvider` for CI/testing.
   - Replay protection & fraud prevention: Unique database constraint `(provider, transaction_id)`. Replays for the same user are idempotent (HTTP 200); attempts across different user accounts are rejected with `HTTP 409 Conflict`.
   - Zero credential exposure: Mobile clients never receive store private keys or webhook secrets.

3. **Centralized Entitlement Service (`backend/app/services/entitlement_service.py`):**
   - Single authority for premium access (`has_entitlement`, `require_entitlement`).
   - Request-time UTC validation: Evaluates `effective_start`, `expires_at`, `is_revoked`, and grace periods at runtime.
   - Low-latency Redis caching (TTL: 300s) with active invalidation on subscription status changes.

4. **Stream & Download Gating (`backend/app/services/audio_service.py`):**
   - High-fidelity audio (192 kbps AAC) requires `PREMIUM_AUDIO_QUALITY`. If a Free user requests HIGH quality, the backend deterministically falls back to MEDIUM (128 kbps) with `is_fallback=True` to preserve playback without crashing.
   - Offline downloads require `OFFLINE_DOWNLOADS` for non-owners. Content creators always retain download and full-fidelity access for their own uploaded tracks.

5. **Server-to-Server Webhook Processing & Deduplication (`backend/app/api/v1/endpoints/subscriptions.py`):**
   - Deduplication via `(provider, provider_event_id)` constraint prevents replay loops.
   - Handles `ACTIVE`, `IN_GRACE_PERIOD`, `CANCELED`, `EXPIRED`, and `REVOKED` lifecycles.

6. **Flutter Mobile Application (`mobile/lib/features/subscriptions/`):**
   - State management via Riverpod: `SubscriptionNotifier`, `subscriptionNotifierProvider`, `isPremiumProvider`.
   - UI Screens:
     - `PremiumPlansScreen` (Paywall): Dynamic plan catalog, value proposition list, billing disclaimers, restore purchases action.
     - `SubscriptionStatusScreen`: Active plan status badge, billing provider, renewal dates, active entitlements list, store management dialog.
   - Navigation: Wired into `app_router.dart` and `profile_screen.dart` with a dynamic membership card.
   - Session Isolation: Automatically invalidates and resets subscription state upon user logout.

---

## Automated Test Results

- **Backend Tests:** 13/13 subscription tests passed. Full suite: **206/206 tests passed**.
- **Frontend Tests:** 10/10 subscription tests passed. Full suite: **290/290 tests passed**.
- **Static Analysis:** `flutter analyze` completed with **0 issues**.
- **Database Migrations:** Clean upgrade and downgrade tested on PostgreSQL.

---

## Verification & Manual Setup Instructions

1. **Local / CI Testing:**
   - Works immediately out of the box using `MockBillingProvider`.
2. **Production Setup:**
   - Apple App Store: Set `APPLE_KEY_ID`, `APPLE_ISSUER_ID`, `APPLE_PRIVATE_KEY` in environment.
   - Google Play: Set `GOOGLE_APPLICATION_CREDENTIALS` service account JSON in environment.
   - Webhook URLs:
     - Apple: `https://api.hums.app/api/v1/webhooks/subscriptions/apple`
     - Google: `https://api.hums.app/api/v1/webhooks/subscriptions/google`
