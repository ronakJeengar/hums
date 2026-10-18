# Hums Subscription Architecture

**Version:** 1.0.0  
**Status:** Active  
**Author:** Principal Software Architect & Senior Backend Engineer  
**Date:** 2026-10-14  

---

## 1. Domain Overview & Decoupling Principle

The Hums monetization system is built on a strict architectural separation of concerns:

- **Subscription (`UserSubscription`)**: Describes the *commercial* relationship between a user and a commercial billing plan (provider, product identifier, billing interval, price, current period start/end, grace period, auto-renew cancellation flag, and authoritative lifecycle status).
- **Entitlement (`Entitlement` & `UserEntitlementGrant`)**: Describes what a user is *operationally permitted to access* in the platform (e.g., `PREMIUM_AUDIO_QUALITY`, `OFFLINE_DOWNLOADS`, `UNLIMITED_DOWNLOADS`).

This separation ensures:
1. Feature gating never inspects raw store receipt tokens, billing provider SKUs, or pricing data.
2. If billing plans change or new promotional bundles are created, feature code remains untouched.
3. Subscriptions in grace periods or canceled states retain active access until `current_period_end` or `grace_period_end` without complex conditional logic in API endpoints.
4. Access can be granted, adjusted, or revoked administratively without altering billing records.

---

## 2. Entity-Relationship Model

```mermaid
erDiagram
    users ||--o{ user_subscriptions : "has"
    users ||--o{ user_entitlement_grants : "holds"
    users ||--o{ subscription_transactions : "purchases"
    subscription_plans ||--o{ user_subscriptions : "defines"
    subscription_plans ||--o{ plan_entitlements : "includes"
    entitlements ||--o{ plan_entitlements : "mapped_to"
    entitlements ||--o{ user_entitlement_grants : "granted_as"
    user_subscriptions ||--o{ user_entitlement_grants : "sources"
    user_subscriptions ||--o{ subscription_transactions : "records"

    subscription_plans {
        uuid id PK
        string code UK "FREE, PREMIUM_MONTHLY, PREMIUM_YEARLY"
        string name
        string description
        string billing_interval "NONE, MONTH, YEAR"
        int price_cents "Minor units"
        string currency "USD"
        string apple_product_id
        string google_product_id
        boolean is_active
        int display_order
        timestamptz created_at
        timestamptz updated_at
    }

    user_subscriptions {
        uuid id PK
        uuid user_id FK
        uuid plan_id FK
        string provider "apple, google, stripe, mock"
        string provider_subscription_id
        string provider_product_id
        string original_transaction_id
        string latest_transaction_id
        string status "PENDING, ACTIVE, IN_GRACE_PERIOD, PAST_DUE, CANCELED, EXPIRED, REVOKED"
        timestamptz current_period_start
        timestamptz current_period_end
        boolean cancel_at_period_end
        timestamptz grace_period_end
        timestamptz canceled_at
        timestamptz created_at
        timestamptz updated_at
    }

    entitlements {
        uuid id PK
        string code UK "PREMIUM_AUDIO_QUALITY, OFFLINE_DOWNLOADS, UNLIMITED_DOWNLOADS"
        string name
        string description
        timestamptz created_at
        timestamptz updated_at
    }

    plan_entitlements {
        uuid id PK
        uuid plan_id FK
        uuid entitlement_id FK
        timestamptz created_at
        timestamptz updated_at
    }

    user_entitlement_grants {
        uuid id PK
        uuid user_id FK
        uuid entitlement_id FK
        uuid source_subscription_id FK
        boolean is_active
        timestamptz effective_start
        timestamptz effective_end
        timestamptz revoked_at
        string revocation_reason
        timestamptz created_at
        timestamptz updated_at
    }

    subscription_transactions {
        uuid id PK
        uuid user_id FK
        uuid subscription_id FK
        string provider
        string transaction_id UK
        string original_transaction_id
        string product_id
        timestamptz purchase_date
        timestamptz expires_date
        string environment
        string raw_data_hash
        timestamptz created_at
        timestamptz updated_at
    }

    subscription_webhook_events {
        uuid id PK
        string provider
        string provider_event_id UK
        string event_type
        string status "RECEIVED, PROCESSED, FAILED, IGNORED"
        string payload_hash
        text error_message
        timestamptz processed_at
        timestamptz created_at
        timestamptz updated_at
    }
```

---

## 3. Subscription Lifecycle State Machine

| State | Definition | Entitlement Access Granted? | Next Valid States |
| :--- | :--- | :--- | :--- |
| `PENDING` | Purchase initiated on client, token submitted, awaiting authoritative verification. | **No** | `ACTIVE`, `CANCELED` |
| `ACTIVE` | Verified, currently active paid period. Auto-renew may or may not be enabled. | **Yes** | `ACTIVE` (renewed), `IN_GRACE_PERIOD`, `PAST_DUE`, `CANCELED`, `REVOKED` |
| `IN_GRACE_PERIOD` | Renewal payment failed, but store allows temporary grace period (e.g. 16 days Apple, 7-14 days Google). | **Yes** (until `grace_period_end`) | `ACTIVE` (recovered), `EXPIRED`, `REVOKED` |
| `PAST_DUE` | Renewal payment failed and no grace period configured; store billing retry in progress. | **No** | `ACTIVE` (recovered), `EXPIRED`, `REVOKED` |
| `CANCELED` | User cancelled auto-renewal. Remains in `CANCELED` state while still entitled until `current_period_end`. | **Yes** (until `current_period_end`) | `ACTIVE` (resubscribed), `EXPIRED`, `REVOKED` |
| `EXPIRED` | Paid period, retry periods, and grace periods have fully elapsed. | **No** | `ACTIVE` (resubscribed) |
| `REVOKED` | Transaction refunded, chargeback issued, or canceled for fraud by store provider. Access ceases immediately. | **No** | [*] Terminal |

---

## 4. Time and Monetary Standards

- **Timezone**: All timestamps are stored and computed in UTC (`DateTime(timezone=True)`).
- **Monetary Representation**: Stored as integer minor units (`price_cents`, e.g. `$9.99` = `999` cents) to avoid floating-point rounding errors.
- **Currency Code**: ISO 4217 uppercase 3-letter codes (default `"USD"`).
- **Grace Period Calculation**: Evaluated dynamically using `utcnow() <= grace_period_end`.
