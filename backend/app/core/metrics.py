import math
import threading
import time
from collections import defaultdict
from typing import Any, Dict, List, Optional, Tuple


class ThreadSafeCounter:
    """Thread-safe counter for low-cardinality metric dimensions."""

    def __init__(self):
        self._lock = threading.Lock()
        self._counts: Dict[Tuple[Tuple[str, str], ...], float] = defaultdict(float)

    def inc(self, amount: float = 1.0, **labels: str) -> None:
        key = tuple(sorted((k, str(v)) for k, v in labels.items()))
        with self._lock:
            self._counts[key] += amount

    def get(self, **labels: str) -> float:
        key = tuple(sorted((k, str(v)) for k, v in labels.items()))
        with self._lock:
            return self._counts.get(key, 0.0)

    def get_all(self) -> List[Dict[str, Any]]:
        with self._lock:
            return [{"labels": dict(k), "value": v} for k, v in self._counts.items()]

    def reset(self) -> None:
        with self._lock:
            self._counts.clear()


class ThreadSafeHistogram:
    """
    Thread-safe latency tracker computing samples, sum, and approximate percentiles (p50, p95, p99).
    Maintains a bounded sliding sample window (max 1,000 samples per label set) to prevent memory growth.
    """

    def __init__(self, max_samples: int = 1000):
        self._lock = threading.Lock()
        self._max_samples = max_samples
        self._samples: Dict[Tuple[Tuple[str, str], ...], List[float]] = defaultdict(list)
        self._sums: Dict[Tuple[Tuple[str, str], ...], float] = defaultdict(float)
        self._counts: Dict[Tuple[Tuple[str, str], ...], int] = defaultdict(int)

    def observe(self, value: float, **labels: str) -> None:
        key = tuple(sorted((k, str(v)) for k, v in labels.items()))
        with self._lock:
            self._counts[key] += 1
            self._sums[key] += value
            samples = self._samples[key]
            if len(samples) >= self._max_samples:
                samples.pop(0)
            samples.append(value)

    def percentiles(self, **labels: str) -> Dict[str, float]:
        key = tuple(sorted((k, str(v)) for k, v in labels.items()))
        with self._lock:
            samples = sorted(self._samples.get(key, []))
            count = self._counts.get(key, 0)
            total_sum = self._sums.get(key, 0.0)

        if not samples:
            return {"count": 0, "sum": 0.0, "p50": 0.0, "p95": 0.0, "p99": 0.0}

        def _p(p: float) -> float:
            idx = int(math.ceil(p * len(samples))) - 1
            return samples[max(0, min(idx, len(samples) - 1))]

        return {
            "count": count,
            "sum": round(total_sum, 4),
            "p50": round(_p(0.50), 4),
            "p95": round(_p(0.95), 4),
            "p99": round(_p(0.99), 4),
        }

    def get_all(self) -> List[Dict[str, Any]]:
        with self._lock:
            keys = list(self._counts.keys())
        results = []
        for key in keys:
            labels = dict(key)
            stats = self.percentiles(**labels)
            results.append({"labels": labels, "stats": stats})
        return results

    def reset(self) -> None:
        with self._lock:
            self._samples.clear()
            self._sums.clear()
            self._counts.clear()


class MetricsRegistry:
    """
    Centralized, lightweight in-memory metrics registry.
    
    Guarantees:
    - Thread-safe updates across ASGI threads.
    - Zero external monitoring server dependencies required.
    - Enforces low-cardinality labels (rejects user_id, track_id, email, etc.).
    - Exports standard Prometheus text format and structured JSON summaries.
    """

    _FORBIDDEN_LABEL_KEYS = {
        "user_id", "owner_id", "track_id", "playlist_id", "email",
        "username", "password", "token", "request_id", "filename"
    }

    def __init__(self):
        # 1. HTTP Request Metrics
        self.http_requests_total = ThreadSafeCounter()
        self.http_errors_total = ThreadSafeCounter()
        self.http_request_duration_seconds = ThreadSafeHistogram()

        # 2. Database Metrics
        self.db_queries_total = ThreadSafeCounter()
        self.db_slow_queries_total = ThreadSafeCounter()
        self.db_query_duration_seconds = ThreadSafeHistogram()

        # 3. Redis Metrics
        self.redis_cache_hits_total = ThreadSafeCounter()
        self.redis_cache_misses_total = ThreadSafeCounter()
        self.redis_errors_total = ThreadSafeCounter()

        # 4. Celery & Worker Metrics
        self.celery_tasks_total = ThreadSafeCounter()
        self.celery_task_duration_seconds = ThreadSafeHistogram()

        # 5. Audio Transcoding Metrics
        self.audio_processing_success_total = ThreadSafeCounter()
        self.audio_processing_failure_total = ThreadSafeCounter()
        self.audio_processing_duration_seconds = ThreadSafeHistogram()

        # 6. AI (Gemini) Job Metrics
        self.ai_requests_total = ThreadSafeCounter()
        self.ai_failures_total = ThreadSafeCounter()
        self.ai_request_duration_seconds = ThreadSafeHistogram()

        # 7. Notification Metrics
        self.notifications_sent_total = ThreadSafeCounter()
        self.notifications_failed_total = ThreadSafeCounter()

        # 8. Mobile Client Playback & Error Metrics
        self.playback_events_total = ThreadSafeCounter()
        self.playback_errors_total = ThreadSafeCounter()
        self.client_runtime_errors_total = ThreadSafeCounter()

    def record_http_request(
        self,
        method: str,
        endpoint: str,
        status_code: int,
        duration_seconds: float,
    ) -> None:
        """Records HTTP request count, error count, and response latency."""
        status_class = f"{status_code // 100}xx"
        clean_method = method.upper()
        clean_endpoint = endpoint or "unknown"

        self.http_requests_total.inc(
            method=clean_method,
            endpoint=clean_endpoint,
            status_code=str(status_code),
        )

        if status_code >= 400:
            self.http_errors_total.inc(
                method=clean_method,
                endpoint=clean_endpoint,
                status_class=status_class,
                status_code=str(status_code),
            )

        self.http_request_duration_seconds.observe(
            duration_seconds,
            method=clean_method,
            endpoint=clean_endpoint,
        )

    def record_db_query(self, operation: str, duration_seconds: float, is_slow: bool = False) -> None:
        """Records database query execution and slow query count."""
        clean_op = operation.upper()
        self.db_queries_total.inc(operation=clean_op)
        self.db_query_duration_seconds.observe(duration_seconds, operation=clean_op)
        if is_slow:
            self.db_slow_queries_total.inc(operation=clean_op)

    def record_redis_hit(self, cache_name: str) -> None:
        self.redis_cache_hits_total.inc(cache_name=cache_name)

    def record_redis_miss(self, cache_name: str) -> None:
        self.redis_cache_misses_total.inc(cache_name=cache_name)

    def record_redis_error(self, operation: str) -> None:
        self.redis_errors_total.inc(operation=operation)

    def record_celery_task(self, task_name: str, status: str, duration_seconds: Optional[float] = None) -> None:
        clean_task = task_name.split(".")[-1]
        self.celery_tasks_total.inc(task=clean_task, status=status.lower())
        if duration_seconds is not None:
            self.celery_task_duration_seconds.observe(duration_seconds, task=clean_task)

    def record_audio_transcode(self, success: bool, duration_seconds: float, failure_category: Optional[str] = None) -> None:
        if success:
            self.audio_processing_success_total.inc()
            self.audio_processing_duration_seconds.observe(duration_seconds)
        else:
            category = failure_category or "unknown"
            self.audio_processing_failure_total.inc(category=category)

    def record_ai_job(self, task_type: str, success: bool, duration_seconds: float, failure_category: Optional[str] = None) -> None:
        status_label = "success" if success else "failure"
        self.ai_requests_total.inc(task_type=task_type, status=status_label)
        self.ai_request_duration_seconds.observe(duration_seconds, task_type=task_type)
        if not success:
            category = failure_category or "unknown"
            self.ai_failures_total.inc(task_type=task_type, category=category)

    def record_playback_event(self, event_type: str, error_category: Optional[str] = None, platform: str = "mobile") -> None:
        self.playback_events_total.inc(event_type=event_type, platform=platform)
        if error_category:
            self.playback_errors_total.inc(category=error_category, platform=platform)

    def generate_prometheus_metrics(self) -> str:
        """Renders all metrics in standard Prometheus exposition text format."""
        lines: List[str] = []

        def _format_labels(labels: Dict[str, str]) -> str:
            if not labels:
                return ""
            pairs = [f'{k}="{v}"' for k, v in sorted(labels.items())]
            return "{" + ",".join(pairs) + "}"

        # 1. HTTP Requests & Errors
        lines.append("# HELP hums_http_requests_total Total number of HTTP requests processed")
        lines.append("# TYPE hums_http_requests_total counter")
        for item in self.http_requests_total.get_all():
            lines.append(f"hums_http_requests_total{_format_labels(item['labels'])} {item['value']}")

        lines.append("# HELP hums_http_errors_total Total number of HTTP error responses")
        lines.append("# TYPE hums_http_errors_total counter")
        for item in self.http_errors_total.get_all():
            lines.append(f"hums_http_errors_total{_format_labels(item['labels'])} {item['value']}")

        lines.append("# HELP hums_http_request_duration_seconds HTTP request latency in seconds")
        lines.append("# TYPE hums_http_request_duration_seconds summary")
        for item in self.http_request_duration_seconds.get_all():
            base_labels = item["labels"]
            stats = item["stats"]
            for q in ["0.5", "0.95", "0.99"]:
                q_key = f"p{int(float(q)*100)}"
                q_labels = dict(base_labels)
                q_labels["quantile"] = q
                lines.append(f"hums_http_request_duration_seconds{_format_labels(q_labels)} {stats.get(q_key, 0.0)}")
            lines.append(f"hums_http_request_duration_seconds_sum{_format_labels(base_labels)} {stats['sum']}")
            lines.append(f"hums_http_request_duration_seconds_count{_format_labels(base_labels)} {stats['count']}")

        # 2. Database Queries
        lines.append("# HELP hums_db_queries_total Total database queries executed")
        lines.append("# TYPE hums_db_queries_total counter")
        for item in self.db_queries_total.get_all():
            lines.append(f"hums_db_queries_total{_format_labels(item['labels'])} {item['value']}")

        lines.append("# HELP hums_db_slow_queries_total Total database queries exceeding threshold")
        lines.append("# TYPE hums_db_slow_queries_total counter")
        for item in self.db_slow_queries_total.get_all():
            lines.append(f"hums_db_slow_queries_total{_format_labels(item['labels'])} {item['value']}")

        # 3. Redis Cache
        lines.append("# HELP hums_redis_cache_hits_total Total Redis cache hits")
        lines.append("# TYPE hums_redis_cache_hits_total counter")
        for item in self.redis_cache_hits_total.get_all():
            lines.append(f"hums_redis_cache_hits_total{_format_labels(item['labels'])} {item['value']}")

        lines.append("# HELP hums_redis_cache_misses_total Total Redis cache misses")
        lines.append("# TYPE hums_redis_cache_misses_total counter")
        for item in self.redis_cache_misses_total.get_all():
            lines.append(f"hums_redis_cache_misses_total{_format_labels(item['labels'])} {item['value']}")

        lines.append("# HELP hums_redis_errors_total Total Redis operations that failed")
        lines.append("# TYPE hums_redis_errors_total counter")
        for item in self.redis_errors_total.get_all():
            lines.append(f"hums_redis_errors_total{_format_labels(item['labels'])} {item['value']}")

        # 4. Celery Tasks
        lines.append("# HELP hums_celery_tasks_total Celery background tasks by status")
        lines.append("# TYPE hums_celery_tasks_total counter")
        for item in self.celery_tasks_total.get_all():
            lines.append(f"hums_celery_tasks_total{_format_labels(item['labels'])} {item['value']}")

        # 5. Audio Processing
        lines.append("# HELP hums_audio_processing_success_total Successful audio transcode jobs")
        lines.append("# TYPE hums_audio_processing_success_total counter")
        for item in self.audio_processing_success_total.get_all():
            lines.append(f"hums_audio_processing_success_total{_format_labels(item['labels'])} {item['value']}")

        lines.append("# HELP hums_audio_processing_failure_total Failed audio transcode jobs")
        lines.append("# TYPE hums_audio_processing_failure_total counter")
        for item in self.audio_processing_failure_total.get_all():
            lines.append(f"hums_audio_processing_failure_total{_format_labels(item['labels'])} {item['value']}")

        # 6. AI Tasks
        lines.append("# HELP hums_ai_requests_total AI Gemini requests by task and status")
        lines.append("# TYPE hums_ai_requests_total counter")
        for item in self.ai_requests_total.get_all():
            lines.append(f"hums_ai_requests_total{_format_labels(item['labels'])} {item['value']}")

        lines.append("# HELP hums_ai_failures_total AI Gemini failures by task and category")
        lines.append("# TYPE hums_ai_failures_total counter")
        for item in self.ai_failures_total.get_all():
            lines.append(f"hums_ai_failures_total{_format_labels(item['labels'])} {item['value']}")

        # 7. Notifications
        lines.append("# HELP hums_notifications_sent_total Successful push notifications dispatched")
        lines.append("# TYPE hums_notifications_sent_total counter")
        for item in self.notifications_sent_total.get_all():
            lines.append(f"hums_notifications_sent_total{_format_labels(item['labels'])} {item['value']}")

        lines.append("# HELP hums_notifications_failed_total Failed push notifications")
        lines.append("# TYPE hums_notifications_failed_total counter")
        for item in self.notifications_failed_total.get_all():
            lines.append(f"hums_notifications_failed_total{_format_labels(item['labels'])} {item['value']}")

        # 8. Mobile Client Playback & Errors
        lines.append("# HELP hums_playback_events_total Client playback telemetry events")
        lines.append("# TYPE hums_playback_events_total counter")
        for item in self.playback_events_total.get_all():
            lines.append(f"hums_playback_events_total{_format_labels(item['labels'])} {item['value']}")

        lines.append("# HELP hums_playback_errors_total Client playback failure events")
        lines.append("# TYPE hums_playback_errors_total counter")
        for item in self.playback_errors_total.get_all():
            lines.append(f"hums_playback_errors_total{_format_labels(item['labels'])} {item['value']}")

        lines.append("# HELP hums_client_runtime_errors_total Client non-fatal runtime error reports")
        lines.append("# TYPE hums_client_runtime_errors_total counter")
        for item in self.client_runtime_errors_total.get_all():
            lines.append(f"hums_client_runtime_errors_total{_format_labels(item['labels'])} {item['value']}")

        return "\n".join(lines) + "\n"

    def get_summary(self) -> Dict[str, Any]:
        """Returns structured JSON snapshot of key metrics for dashboards."""
        return {
            "http": {
                "requests": self.http_requests_total.get_all(),
                "errors": self.http_errors_total.get_all(),
                "duration": self.http_request_duration_seconds.get_all(),
            },
            "database": {
                "queries": self.db_queries_total.get_all(),
                "slow_queries": self.db_slow_queries_total.get_all(),
                "duration": self.db_query_duration_seconds.get_all(),
            },
            "redis": {
                "hits": self.redis_cache_hits_total.get_all(),
                "misses": self.redis_cache_misses_total.get_all(),
                "errors": self.redis_errors_total.get_all(),
            },
            "celery": {
                "tasks": self.celery_tasks_total.get_all(),
                "duration": self.celery_task_duration_seconds.get_all(),
            },
            "audio": {
                "success": self.audio_processing_success_total.get_all(),
                "failures": self.audio_processing_failure_total.get_all(),
                "duration": self.audio_processing_duration_seconds.get_all(),
            },
            "ai": {
                "requests": self.ai_requests_total.get_all(),
                "failures": self.ai_failures_total.get_all(),
                "duration": self.ai_request_duration_seconds.get_all(),
            },
            "playback": {
                "events": self.playback_events_total.get_all(),
                "errors": self.playback_errors_total.get_all(),
                "client_errors": self.client_runtime_errors_total.get_all(),
            },
        }

    def reset_all(self) -> None:
        """Resets all metrics (primarily for test isolation)."""
        self.http_requests_total.reset()
        self.http_errors_total.reset()
        self.http_request_duration_seconds.reset()
        self.db_queries_total.reset()
        self.db_slow_queries_total.reset()
        self.db_query_duration_seconds.reset()
        self.redis_cache_hits_total.reset()
        self.redis_cache_misses_total.reset()
        self.redis_errors_total.reset()
        self.celery_tasks_total.reset()
        self.celery_task_duration_seconds.reset()
        self.audio_processing_success_total.reset()
        self.audio_processing_failure_total.reset()
        self.audio_processing_duration_seconds.reset()
        self.ai_requests_total.reset()
        self.ai_failures_total.reset()
        self.ai_request_duration_seconds.reset()
        self.notifications_sent_total.reset()
        self.notifications_failed_total.reset()
        self.playback_events_total.reset()
        self.playback_errors_total.reset()
        self.client_runtime_errors_total.reset()


# Global singleton metrics registry
metrics_registry = MetricsRegistry()
