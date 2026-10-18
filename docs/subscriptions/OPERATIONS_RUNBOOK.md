# Subscriptions & Premium Operations Runbook

## 1. Deployment & Migration Procedure

### Pre-Deployment Verification

1. Verify environment secrets in production secret manager (e.g. AWS Secrets Manager, Vault, or Kubernetes Secrets):
   - `APPLE_KEY_ID`: 10-character key identifier from App Store Connect
   - `APPLE_ISSUER_ID`: UUID issuer identifier from App Store Connect
   - `APPLE_PRIVATE_KEY`: Content of `.p8` private key file
   - `GOOGLE_APPLICATION_CREDENTIALS_JSON`: Service account JSON with Android Publisher permissions
   - `BILLING_ENVIRONMENT`: Set to `production` (or `sandbox` on staging)
2. Verify Redis cluster is reachable and healthy.

### Database Migration

Apply the database migration to PostgreSQL before deploying application instances:

```bash
cd backend
source .venv/bin/activate
alembic upgrade head
```

Verify migration status:
```bash
alembic current
# Expected revision: 20260929_d0e123456789
```

### Plan Catalog Initialization

If running on a fresh environment, verify default plans are seeded:

```sql
SELECT id, code, name, billing_interval, is_active FROM subscription_plans;
```

Expected plans:
- `FREE`: Free Tier ($0.00)
- `PREMIUM_MONTHLY`: Hums Premium Monthly ($9.99/mo)
- `PREMIUM_YEARLY`: Hums Premium Annual ($99.99/yr)

---

## 2. Key Observability Metrics & Alerts

All metrics are exposed at `GET /metrics` in Prometheus format:

| Metric Name | Type | Warning Threshold | Critical Threshold | Action |
| :--- | :--- | :--- | :--- | :--- |
| `subscription_verifications_total{status="failure"}` | Counter | > 5 failures in 5m | > 20 failures in 5m | Check provider credentials & Apple/Google API status |
| `billing_provider_latency_seconds` | Histogram | p95 > 2.0s | p95 > 5.0s | Upstream store API latency degradation |
| `webhook_duplicate_events_total` | Counter | Infrequent duplicates normal | > 100/min | Possible upstream retry loop or network glitch |
| `entitlement_denials_total` | Counter | Monitored for baseline | Sudden 10x spike | Check for expired auth tokens or cache desync |

---

## 3. Incident Response Playbooks

### Incident A: User Reports Store Payment Succeeded but App Shows Free Tier

1. **Locate the Transaction in Logs & Database:**
   ```sql
   SELECT * FROM subscription_transactions
   WHERE provider_transaction_id = '<store_transaction_id>'
      OR user_id = '<user_uuid>';
   ```
2. **Check Webhook Processing:**
   ```sql
   SELECT * FROM subscription_webhook_events
   WHERE payload::text LIKE '%<store_transaction_id>%'
   ORDER BY created_at DESC;
   ```
3. **Trigger Manual Restore:**
   Advise the user to tap **Profile > Subscription > Restore** in the mobile app. This calls `POST /api/v1/subscriptions/restore`, re-querying the store provider.
4. **Emergency Manual Entitlement Grant (if store API is temporarily unreachable):**
   ```sql
   -- Insert temporary manual grant
   INSERT INTO user_entitlement_grants (id, user_id, entitlement_code, status, effective_start, expires_at, created_at, updated_at)
   VALUES (
     gen_random_uuid(),
     '<user_uuid>',
     'PREMIUM_AUDIO_QUALITY',
     'ACTIVE',
     NOW(),
     NOW() + INTERVAL '7 days',
     NOW(),
     NOW()
   );
   ```
5. **Flush User Redis Cache:**
   ```bash
   redis-cli DEL "entitlements:user:<user_uuid>"
   ```

### Incident B: Provider Verification Spike Failures (HTTP 502 / 400)

1. Check store system status pages:
   - Apple Developer System Status: `https://developer.apple.com/system-status/`
   - Google Play Status Dashboard: `https://status.play.google.com/`
2. Check JWT expiration for Apple App Store Server API:
   - Private key tokens expire after 60 minutes. Verify server clock is synchronized via NTP.
3. Verify `BILLING_ENVIRONMENT`:
   - If sandbox transactions are being sent to production endpoints or vice-versa, verify client build environment matching backend environment.

### Incident C: Cross-Account Replay Alerts (HTTP 409)

1. Query transactions table for duplicate attempts:
   ```sql
   SELECT user_id, provider, provider_transaction_id, created_at
   FROM subscription_transactions
   WHERE provider_transaction_id = '<transaction_id>';
   ```
2. If multiple distinct user accounts attempt to verify the exact same store transaction, the second attempt is rejected with `409 Conflict`.
3. If legitimate (e.g. user created a new Hums account and wants to transfer their subscription), instruct user on account recovery.

---

## 4. Cache Management

Entitlement checks are cached in Redis with a 300-second TTL.

- Cache Key Pattern: `entitlements:user:{user_id}`
- To invalidate a single user:
  ```bash
  redis-cli DEL "entitlements:user:<user_id>"
  ```
- To invalidate all subscription caches during deployment:
  ```bash
  redis-cli --scan --pattern "entitlements:user:*" | xargs -r redis-cli DEL
  ```
