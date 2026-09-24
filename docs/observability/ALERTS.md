# Hums — Production Alerting Rules & SLO Specifications

This document defines the production alerting thresholds, SLOs, PromQL alert expressions, and operational severity matrix for Hums.

---

## 1. Alert Severity Matrix

| Severity | Target Response Time | Notification Channel | Description |
| :--- | :--- | :--- | :--- |
| **P1 — Critical** | Immediate (< 15 mins) | PagerDuty / On-call Phone | Core user journey is broken (e.g. playback completely down, API 503, database down). |
| **P2 — High** | < 1 hour | Slack `#alerts-prod` + PagerDuty | Degraded user experience (elevated latency, background worker queue backlog, transcode failures). |
| **P3 — Medium** | < 4 hours | Slack `#alerts-prod` | Non-blocking issues (cache miss spike, slow query warnings, minor non-fatal client errors). |
| **P4 — Low / Info** | Next business day | Slack `#alerts-dev` | Metric trends, capacity planning warnings, minor quota consumption. |

---

## 2. Core Service-Level Objectives (SLOs)

- **API Availability**: $\ge 99.9\%$ successful HTTP requests ($< 0.1\%$ 5xx errors) over any rolling 30-day window.
- **API Latency**: $95\%$ of read requests complete in $< 150\text{ms}$; $99\%$ complete in $< 500\text{ms}$.
- **Audio Playback Reliability**: $< 1.0\%$ playback initiation errors across active client sessions.
- **Audio Transcoding SLA**: $99\%$ of uploaded tracks transcoded and ready for streaming within 60 seconds.

---

## 3. Production Alert Definitions

### 1. API High Error Rate (5xx)
- **Severity**: P1 — Critical
- **Summary**: Elevated HTTP 5xx server error rate across API endpoints.
- **Condition**: 5xx error rate exceeds $1\%$ of total requests over a 5-minute rolling window.
- **PromQL Expression**:
  ```promql
  sum(rate(hums_http_errors_total{status_class="5xx"}[5m]))
  /
  sum(rate(hums_http_requests_total[5m])) > 0.01
  ```
- **Impact**: Users receive failure errors on registration, login, library browsing, or playback initialization.
- **Action**: Check `OPERATIONS_RUNBOOK.md#runbook-1-investigating-high-api-5xx-errors`.

---

### 2. API Latency Degradation (p95 / p99)
- **Severity**: P2 — High
- **Summary**: High response latency on core API routes.
- **Condition**: p95 latency exceeds 500ms or p99 latency exceeds 2000ms for $\ge 5$ minutes.
- **PromQL Expression**:
  ```promql
  hums_http_request_duration_seconds{quantile="0.95"} > 0.50
  ```
- **Impact**: Sluggish app navigation, delayed search results, track list loading delays.
- **Action**: Check `OPERATIONS_RUNBOOK.md#runbook-2-investigating-api-latency-spikes`.

---

### 3. Database Connection Pool Saturation
- **Severity**: P1 — Critical
- **Summary**: SQLAlchemy connection pool is nearing complete exhaustion.
- **Condition**: `checked_out / (pool_size + overflow) > 0.85` for $> 3$ consecutive minutes.
- **PromQL Expression**:
  ```promql
  hums_db_pool_checked_out / (hums_db_pool_size + hums_db_pool_overflow) > 0.85
  ```
- **Impact**: Incoming database requests queue up and eventually fail with `TimeoutError`, resulting in widespread 500 errors.
- **Action**: Check `OPERATIONS_RUNBOOK.md#runbook-3-investigating-database-pool-exhaustion`.

---

### 4. Database Slow Query Surge
- **Severity**: P3 — Medium
- **Summary**: High frequency of queries exceeding the slow query execution threshold (`DB_SLOW_QUERY_MS`).
- **Condition**: $> 10$ slow queries per minute for 5 consecutive minutes.
- **PromQL Expression**:
  ```promql
  sum(rate(hums_db_slow_queries_total[5m])) * 60 > 10
  ```
- **Impact**: High database CPU utilization, connection pool queuing.
- **Action**: Check PostgreSQL `pg_stat_statements` and application logs for `SLOW QUERY` entries.

---

### 5. Redis Broker / Cache Disconnected
- **Severity**: P1 — Critical
- **Summary**: Application instances cannot communicate with Redis.
- **Condition**: Readiness probe reports Redis disconnected OR `rate(hums_redis_errors_total[2m]) > 0`.
- **PromQL Expression**:
  ```promql
  rate(hums_redis_errors_total[2m]) > 0
  ```
- **Impact**: Rate limiting, caching, session validation, and Celery task dispatching fail.
- **Action**: Check `OPERATIONS_RUNBOOK.md#runbook-4-investigating-redis-failures`.

---

### 6. Celery Task Queue Backlog
- **Severity**: P2 — High
- **Summary**: Celery audio transcoding and AI jobs are accumulating in the Redis queue without being processed.
- **Condition**: Pending task depth in Redis exceeds 100 tasks for $> 10$ minutes.
- **PromQL Expression**:
  ```promql
  hums_celery_queue_depth{queue="celery"} > 100
  ```
- **Impact**: Creator uploads remain stuck in "processing" state; recommendations and AI summaries stall.
- **Action**: Check `OPERATIONS_RUNBOOK.md#runbook-5-investigating-celery-worker-backlog`.

---

### 7. Audio Transcoding Failure Rate
- **Severity**: P2 — High
- **Summary**: Spike in FFmpeg audio transcoding failures.
- **Condition**: Transcode failures exceed $5\%$ of total completed jobs over a 15-minute window.
- **PromQL Expression**:
  ```promql
  sum(rate(hums_audio_processing_failure_total[15m]))
  /
  (sum(rate(hums_audio_processing_success_total[15m])) + sum(rate(hums_audio_processing_failure_total[15m]))) > 0.05
  ```
- **Impact**: Uploaded tracks fail to become streamable.
- **Action**: Check `OPERATIONS_RUNBOOK.md#runbook-6-investigating-audio-transcoding-failures`.

---

### 8. Gemini AI Failure Surge
- **Severity**: P3 — Medium
- **Summary**: High error rate communicating with Gemini API for recommendation tags or summaries.
- **Condition**: AI task failures exceed $15\%$ over a 10-minute window.
- **PromQL Expression**:
  ```promql
  sum(rate(hums_ai_failures_total[10m]))
  /
  sum(rate(hums_ai_requests_total[10m])) > 0.15
  ```
- **Impact**: AI recommendation enrichment falls back to heuristic algorithms.
- **Action**: Inspect quota limits, API key validity, and rate limits with Google Gemini API.

---

### 9. Client Playback Failure Rate Surge
- **Severity**: P1 — Critical
- **Summary**: Elevated audio playback failure rate reported by mobile clients.
- **Condition**: Mobile playback error rate exceeds $2.0\%$ of total playback starts over a 10-minute window.
- **PromQL Expression**:
  ```promql
  sum(rate(hums_playback_errors_total[10m]))
  /
  sum(rate(hums_playback_events_total{event_type="play_started"}[10m])) > 0.02
  ```
- **Impact**: Mobile users experience stream drops, silent failures, or media decode crashes.
- **Action**: Check `OPERATIONS_RUNBOOK.md#runbook-7-investigating-mobile-playback-failures`.

---

### 10. Service Readiness Probe Failure
- **Severity**: P1 — Critical
- **Summary**: An instance is failing its readiness probe and is removed from the load balancer.
- **Condition**: HTTP status of `/health/ready` returns 503 for $> 1$ minute.
- **PromQL Expression**:
  ```promql
  probe_success{instance=~".*", job="hums-readiness"} == 0
  ```
- **Impact**: Traffic drops or shifts to surviving instances, risking cascade failure.
- **Action**: Check `/health/ready` JSON response to identify which dependency is failing (`database`, `redis`, `storage`, `celery_broker`).
