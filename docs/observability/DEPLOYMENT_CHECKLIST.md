# Hums — Production Observability Deployment Checklist

This checklist must be executed and signed off prior to rolling out observability updates or promoting releases to production.

---

## 1. Environment & Configuration Verification

- [ ] **Logging Format Set Correctly**:
  - `LOG_FORMAT="auto"` or `LOG_FORMAT="json"` configured in production environment (`.env`).
  - `DEBUG=false` in production.
- [ ] **Database Slow Query Threshold Configured**:
  - `DB_SLOW_QUERY_MS=100.0` (or target SLA value).
- [ ] **Metrics Feature Flag**:
  - `METRICS_ENABLED=true`.
- [ ] **Broker & Storage Credentials**:
  - `REDIS_URL`, `CELERY_BROKER_URL`, and MinIO/S3 variables are set and validated.

---

## 2. Health Probe Endpoints Verification

Verify all three health probe endpoints using `curl`:

1. **Process Liveness Probe**:
   ```bash
   curl -i http://localhost:8000/health/live
   ```
   - [ ] Returns HTTP `200 OK`.
   - [ ] Body contains `{"status": "alive", "app": "Hums", ...}`.
   - [ ] Does not perform database or Redis queries.

2. **Readiness Probe**:
   ```bash
   curl -i http://localhost:8000/health/ready
   ```
   - [ ] Returns HTTP `200 OK` when PostgreSQL and Redis are accessible.
   - [ ] Returns HTTP `503 Service Unavailable` if PostgreSQL or Redis is offline.
   - [ ] Body contains detailed subsystem health map.

3. **Backward-Compatible Root Probe**:
   ```bash
   curl -i http://localhost:8000/health
   ```
   - [ ] Returns HTTP `200 OK` with `{"status": "healthy"}`.

---

## 3. Metrics Exposition Verification

1. **Prometheus Text Metrics**:
   ```bash
   curl -i http://localhost:8000/metrics
   ```
   - [ ] Returns HTTP `200 OK`.
   - [ ] Content-Type is `text/plain; version=0.0.4`.
   - [ ] Core metrics are present:
     - `# HELP hums_http_requests_total`
     - `# HELP hums_http_request_duration_seconds`
     - `# HELP hums_db_queries_total`
     - `# HELP hums_celery_tasks_total`
     - `# HELP hums_playback_events_total`
   - [ ] Endpoints use route templates (`/api/v1/playlists/{playlist_id}`) without raw IDs.

2. **Structured JSON Metrics Summary**:
   ```bash
   curl -i http://localhost:8000/api/v1/metrics
   ```
   - [ ] Returns HTTP `200 OK` with valid JSON dictionary containing `http`, `database`, `redis`, `celery`, and `playback` keys.

---

## 4. Request Correlation & Log Privacy Verification

1. **Header Propagation**:
   ```bash
   curl -i -H "X-Request-ID: test-deploy-audit-12345" http://localhost:8000/health/live
   ```
   - [ ] Response contains header `X-Request-ID: test-deploy-audit-12345`.
   - [ ] Missing header generates fresh UUIDv4.

2. **Sensitive Data Redaction Audit**:
   - [ ] Check logs during authentication attempts:
     - Authorization header `Bearer [REDACTED]` is masked.
     - Payload password fields `"password": "[REDACTED]"` are masked.
     - Database connection strings hide passwords.
     - MinIO signed URLs mask `X-Amz-Signature=[REDACTED]`.

---

## 5. Database & Worker Telemetry Verification

1. **Database Hooks**:
   - [ ] Execute an API call (`GET /api/v1/tracks`).
   - [ ] Query count in `hums_db_queries_total` increments.
   - [ ] Connection pool status returns valid counts via `get_db_pool_status()`.

2. **Celery Worker Signals**:
   - [ ] Celery worker boots with signal listeners connected (`task_prerun`, `task_postrun`, `task_failure`, `task_retry`).
   - [ ] `get_celery_queue_depth()` returns non-negative queue length.

---

## 6. Client Telemetry Pipeline Verification

1. **Batch Ingestion Endpoint**:
   ```bash
   curl -i -X POST http://localhost:8000/api/v1/telemetry/events \
     -H "Content-Type: application/json" \
     -d '{"events": [{"event_type": "play_started", "platform": "ios"}], "errors": []}'
   ```
   - [ ] Returns HTTP `200 OK` with `{"success": true, "data": {"message": "Telemetry accepted"}}`.
   - [ ] Metric `hums_playback_events_total` increments.
   - [ ] Batches exceeding limit (> 50 events) are rejected with HTTP 422 (DoS protection).

2. **Flutter Mobile Telemetry Service**:
   - [ ] Service buffers playback events and flushes periodically.
   - [ ] Network disconnects do not interrupt audio playback (fail-open).
   - [ ] Global unhandled exceptions captured via `FlutterError.onError`.

---

## 7. Automated Test Suite Gate

Both test suites must pass 100% with zero regressions:

- [ ] **Backend Test Suite**:
  ```bash
  source backend/.venv/bin/activate
  pytest backend/
  ```
  *Requirement: 105 passed, 0 failed.*

- [ ] **Flutter Mobile Test Suite**:
  ```bash
  cd mobile
  flutter test
  ```
  *Requirement: 123 passed, 0 failed.*

---

## 8. Rollback Triggers & Contingency Plan

Abort and trigger immediate rollback to previous release tag if any of the following occur within 30 minutes of deployment:
- API 5xx error rate $> 0.5\%$.
- Application pod readiness probe fails on $> 25\%$ of fleet.
- Database connection pool reaches 100% saturation.
- Client playback failure rate spikes above $2\%$.
