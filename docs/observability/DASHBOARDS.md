# Hums — Production Monitoring Dashboards Specification

This document provides complete layout and panel specifications for Grafana or Datadog dashboards monitoring Hums.

---

## Dashboard 1: Executive & Golden Signals (Primary Triage)

The single-pane-of-glass dashboard for on-call engineers to evaluate overall platform health at a glance.

```text
+---------------------------------------------------------------------------------------------------+
|  [Traffic: Req/sec]           |  [Error Rate: % 5xx]         |  [Latency: p95 & p99]              |
|  sum(rate(requests[1m]))      |  5xx Rate / Total Rate       |  hums_http_request_duration_seconds |
+-------------------------------+------------------------------+------------------------------------+
|  [Database Saturation]        |  [Celery Queue Backlog]      |  [Mobile Playback Error Rate]      |
|  CheckedOut / Pool Capacity   |  Queue Depth (LLEN)          |  Playback Errors / Play Starts     |
+---------------------------------------------------------------------------------------------------+
|  [Service Readiness Status Grid]                                                                 |
|  FastAPI Pods: OK | Postgres: Connected | Redis: Connected | Celery: Active | Storage: Connected  |
+---------------------------------------------------------------------------------------------------+
```

### Key Panels
1. **Traffic (RPS)**:
   - Metric: `sum(rate(hums_http_requests_total[1m]))`
   - Visualization: Time series line chart.
2. **Error Rate (%)**:
   - Metric: `sum(rate(hums_http_errors_total{status_class="5xx"}[1m])) / sum(rate(hums_http_requests_total[1m])) * 100`
   - Thresholds: Yellow > 0.5%, Red > 1.0%.
3. **Latency (Percentiles)**:
   - Metrics: p50 (median), p95, p99 from `hums_http_request_duration_seconds`.
   - Thresholds: p95 > 250ms (warning), p95 > 500ms (critical).
4. **Active Instances & Readiness**:
   - Status indicators evaluating `/health/ready` response per node.

---

## Dashboard 2: API & Route Performance

Provides granular breakdown of HTTP endpoint performance and client error patterns.

### Panels
1. **Request Volume by Route**:
   - PromQL: `sum by (endpoint) (rate(hums_http_requests_total[5m]))`
   - Visualization: Stacked area chart showing top 10 most active endpoints.
2. **Error Breakdown by Status Code & Route**:
   - PromQL: `sum by (status_code, endpoint) (rate(hums_http_errors_total[5m]))`
   - Visualization: Bar chart highlighting 400, 401, 403, 404, 422, 429, and 500.
3. **Slowest Routes (Top 5)**:
   - PromQL: `topk(5, hums_http_request_duration_seconds{quantile="0.95"})`
   - Visualization: Table with Route, p50, p95, p99, and Requests/sec.
4. **Rate Limit Throttling (429s)**:
   - PromQL: `sum(rate(hums_http_requests_total{status_code="429"}[5m]))`
   - Identifies whether users or abusive bots are getting throttled.

---

## Dashboard 3: Database & Cache Performance

Monitors PostgreSQL connection pooling, query execution latency, and Redis cache efficiency.

### Panels
1. **SQLAlchemy Connection Pool Saturation**:
   - Metrics:
     - `hums_db_pool_checked_out`
     - `hums_db_pool_checked_in`
     - `hums_db_pool_overflow`
     - `hums_db_pool_size`
   - Threshold: Alert if `checked_out / (pool_size + overflow) > 0.85`.
2. **Query Throughput by Operation**:
   - PromQL: `sum by (operation) (rate(hums_db_queries_total[1m]))`
   - Tracks SELECT, INSERT, UPDATE, DELETE distribution.
3. **Slow Query Rate**:
   - PromQL: `sum by (operation) (rate(hums_db_slow_queries_total[5m]))`
   - Identifies when unindexed or expensive queries spike.
4. **Database Query Latency Percentiles**:
   - Metrics: `hums_db_query_duration_seconds` (p50, p95, p99).
5. **Redis Cache Hit vs. Miss Ratio**:
   - PromQL Hit Ratio: `sum(rate(hums_redis_cache_hits_total[5m])) / (sum(rate(hums_redis_cache_hits_total[5m])) + sum(rate(hums_redis_cache_misses_total[5m]))) * 100`
   - Target: $\ge 80\%$ hit ratio on track metadata and profile caches.
6. **Redis Operation Errors**:
   - PromQL: `sum by (operation) (rate(hums_redis_errors_total[1m]))`

---

## Dashboard 4: Celery Background Workers & Audio Transcoding

Monitors asynchronous processing pipelines, FFmpeg transcode jobs, and task lifecycle.

### Panels
1. **Celery Task Throughput by Status**:
   - PromQL: `sum by (task, status) (rate(hums_celery_tasks_total[5m]))`
   - Displays started vs. success vs. failure vs. retry.
2. **Celery Queue Depth (Backlog)**:
   - Metric: `hums_celery_queue_depth`
   - Threshold: Yellow > 25, Red > 100 pending tasks.
3. **Task Duration by Worker Task**:
   - Metric: `hums_celery_task_duration_seconds{quantile="0.95"}`
   - Specifically tracks `process_audio_track` and AI enrichment tasks.
4. **Audio Transcoding Success Rate (%)**:
   - PromQL: `sum(rate(hums_audio_processing_success_total[15m])) / (sum(rate(hums_audio_processing_success_total[15m])) + sum(rate(hums_audio_processing_failure_total[15m]))) * 100`
   - Target: $\ge 99\%$.
5. **Audio Failure Breakdown by Category**:
   - PromQL: `sum by (category) (rate(hums_audio_processing_failure_total[15m]))`
   - Categorized by: `media_codec_error`, `storage_error`, `timeout`, `application_error`.

---

## Dashboard 5: AI & Recommendation Services

Monitors Google Gemini AI integration and recommendation engine performance.

### Panels
1. **Gemini Request Volume**:
   - PromQL: `sum by (task_type) (rate(hums_ai_requests_total{status="success"}[5m]))`
2. **AI Failure Rate**:
   - PromQL: `sum by (task_type) (rate(hums_ai_failures_total[5m])) / sum by (task_type) (rate(hums_ai_requests_total[5m])) * 100`
3. **Gemini API Call Duration**:
   - Metric: `hums_ai_request_duration_seconds{quantile="0.95"}`
4. **Failure Reasons**:
   - Breakdown by category (`rate_limit`, `quota_exceeded`, `timeout`, `invalid_response`).

---

## Dashboard 6: Mobile Client Health & Audio Playback

Visualizes real-user mobile client telemetry ingested via `/api/v1/telemetry/events`.

### Panels
1. **Active Playback Starts**:
   - PromQL: `sum by (platform) (rate(hums_playback_events_total{event_type="play_started"}[5m]))`
   - Visualizes iOS vs. Android playback volume.
2. **Buffering & Stalls Rate**:
   - PromQL: `sum by (platform) (rate(hums_playback_events_total{event_type="buffering_started"}[5m]))`
3. **Playback Error Frequency**:
   - PromQL: `sum by (category, platform) (rate(hums_playback_errors_total[5m]))`
   - Breakdown by: `buffer_underrun`, `decoder_error`, `network_disconnect`, `http_403`.
4. **Client-Side Runtime Exceptions**:
   - PromQL: `sum by (error_type, platform) (rate(hums_client_runtime_errors_total[5m]))`
   - Surfaces non-fatal Flutter exceptions before users report them.
