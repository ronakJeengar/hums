# Platform In-App Billing Guide

## 1. Regulatory & Compliance Context

Both Apple and Google strictly mandate using their native In-App Purchase (IAP) billing systems for unlocking digital features, premium audio streaming, and offline downloads inside iOS and Android mobile apps:

- **Apple App Store Review Guideline 3.1.1:** Apps offering digital goods, subscriptions, or premium streaming must use In-App Purchase. Out-of-app links or alternate payment mechanisms are rejected during App Store review.
- **Google Play Payments Policy:** All transactions involving in-app digital features, premium subscriptions, and offline audio downloads must process through Google Play Billing.

---

## 2. Apple App Store Setup (StoreKit 2)

### A. App Store Connect Configuration

1. **Subscription Group:**
   - Group Name: `Hums Premium Access`
   - Group ID: Configured in App Store Connect
2. **Products:**
   - Monthly: `com.hums.monthly` (Reference Name: `Hums Premium Monthly`)
   - Annual: `com.hums.yearly` (Reference Name: `Hums Premium Annual`)
3. **App Store Server Notifications V2:**
   - Production URL: `https://api.hums.app/api/v1/webhooks/subscriptions/apple`
   - Sandbox URL: `https://staging-api.hums.app/api/v1/webhooks/subscriptions/apple`
   - Version: Select **Version 2 Notifications**
4. **App Store Server API Credentials:**
   - In App Store Connect > Users and Access > Integrations > App Store Server API:
   - Generate an API Key with **In-App Purchase** role.
   - Note down: `APPLE_KEY_ID`, `APPLE_ISSUER_ID`, and download the private key (`.p8`).

### B. StoreKit 2 Testing Boundary

- In Xcode: Use a local `.storekit` testing configuration file to simulate successful purchases, renewals, grace periods, and cancellations in the iOS Simulator.
- In Sandbox: Create Sandbox Apple ID accounts under App Store Connect > Users and Access > Sandbox.
- Restore Purchases: Apple mandates a visible "Restore Purchases" button on every paywall screen and settings screen. Hums implements this on both `PremiumPlansScreen` and `SubscriptionStatusScreen`.

---

## 3. Google Play Billing Setup

### A. Google Play Console Configuration

1. **Subscriptions Configuration:**
   - Subscription ID: `hums_premium`
   - Base Plans:
     - `monthly-plan`: Cadence: 1 month, Auto-renewing
     - `yearly-plan`: Cadence: 1 year, Auto-renewing
2. **Grace Period & Account Hold:**
   - Enable **Grace Period**: 16 days (maintains user access while Google retries payment).
   - Enable **Account Hold**: 30 days (suspends access without canceling subscription).
3. **Real-Time Developer Notifications (RTDN):**
   - Create a Google Cloud Pub/Sub topic: `projects/hums-production/topics/play-billing-notifications`.
   - Grant Publish rights to `google-play-developer-notifications@system.gserviceaccount.com`.
   - Create a push subscription pointing to `https://api.hums.app/api/v1/webhooks/subscriptions/google`.

### B. Purchase Acknowledgment Requirement

- **Critical Rule:** Every Google Play subscription purchase must be acknowledged by the server or client within **3 days**. If unacknowledged, Google Play automatically refunds the purchase and revokes the subscription.
- Hums server acknowledges verified purchases immediately upon processing in `backend/app/services/billing/google_provider.py`.

---

## 4. Flutter Integration Boundary

The mobile application communicates with native billing APIs while keeping all verification logic server-authoritative:

```
+-----------------------------------------------------------+
|                      Flutter UI                           |
|  - PremiumPlansScreen (Paywall)                           |
|  - SubscriptionStatusScreen (Management & Restore)        |
+-----------------------------+-----------------------------+
                              |
                              v
+-----------------------------------------------------------+
|                 SubscriptionNotifier                      |
|  - Initiates store flow via platform provider             |
|  - Submits purchase token to backend API                  |
|  - Authoritatively loads updated entitlements             |
+-----------------------------+-----------------------------+
                              |
                              v
+-----------------------------------------------------------+
|                  Backend FastAPI API                      |
|  - POST /api/v1/subscriptions/verify-purchase             |
|  - POST /api/v1/subscriptions/restore                     |
+-----------------------------------------------------------+
```

### Supported Integration Boundary & Safe Fallback
When live store credentials (`APPLE_KEY_ID` or `GOOGLE_APPLICATION_CREDENTIALS`) are not yet provisioned:
- In `development` and `test` environments: The system uses `MockBillingProvider` which generates deterministic verified subscriptions without hitting live Apple/Google networks.
- In `production`: Mock provider is disabled. If credentials are missing, the server logs a critical configuration warning and rejects unverified purchases rather than simulating fake success.
