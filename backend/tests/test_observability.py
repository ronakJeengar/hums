"""Observability & Monitoring Automated Test Suite.

Verifies:
- Request ID correlation, generation, validation, and header propagation.
- Health checks: shallow liveness (/health/live), readiness (/health/ready), and deep health (/api/v1/health).
- Prometheus metrics exposition (/metrics) and JSON metrics summary (/api/v1/metrics).
- Client telemetry ingestion (/api/v1/telemetry/events) and metric increments.
- Sensitive data masking in structured logging (SensitiveDataFilter).
- Database query observability and connection pool stats.
- Celery failure categorization.
"""

import json
import logging
import pytest
from httpx import AsyncClient
from unittest.mock import AsyncMock, patch

from app.core.context import get_request_id, set_request_id, clear_request_id
from app.core.logging import SensitiveDataFilter, StructuredJSONFormatter
from app.core.metrics import metrics_registry
from app.db.observability import get_db_pool_status
from app.workers.observability import categorize_task_failure


# ---------------------------------------------------------------------------
# Request Correlation Tests
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_request_id_generated_when_missing(async_client: AsyncClient):
    """Verifies that an incoming request without X-Request-ID gets a valid UUID assigned."""
    response = await async_client.get("/health/live")
    assert response.status_code == 200
    assert "x-request-id" in response.headers
    req_id = response.headers["x-request-id"]
    assert len(req_id) >= 16
    assert "-" in req_id


@pytest.mark.asyncio
async def test_request_id_propagated_when_provided(async_client: AsyncClient):
    """Verifies that a valid client-supplied X-Request-ID is preserved across the response."""
    custom_id = "test-req-trace-abc-12345"
    response = await async_client.get("/health/live", headers={"x-request-id": custom_id})
    assert response.status_code == 200
    assert response.headers["x-request-id"] == custom_id


@pytest.mark.asyncio
async def test_request_id_sanitized_when_malformed(async_client: AsyncClient):
    """Verifies that malicious or oversized request IDs are sanitized/replaced."""
    malformed_id = "bad\nheader\rvalue" + "x" * 200
    response = await async_client.get("/health/live", headers={"x-request-id": malformed_id})
    assert response.status_code == 200
    returned_id = response.headers["x-request-id"]
    assert returned_id != malformed_id
    assert len(returned_id) >= 16


def test_context_request_id_lifecycle():
    """Verifies ContextVar get/set/clear lifecycle."""
    clear_request_id()
    assert get_request_id() == "system"
    set_request_id("ctx-trace-999")
    assert get_request_id() == "ctx-trace-999"
    clear_request_id()
    assert get_request_id() == "system"


# ---------------------------------------------------------------------------
# Health Check Tests
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_liveness_endpoint_healthy(async_client: AsyncClient):
    """Liveness probe must return 200 without executing deep dependency checks."""
    response = await async_client.get("/health/live")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "alive"


@pytest.mark.asyncio
async def test_readiness_endpoint_healthy(async_client: AsyncClient):
    """Readiness probe returns 200 when database and redis dependencies are healthy."""
    response = await async_client.get("/health/ready")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ready"
    assert data["services"]["database"] == "connected"
    assert data["services"]["redis"] == "connected"


@pytest.mark.asyncio
async def test_readiness_endpoint_fails_when_db_down(async_client: AsyncClient):
    """Readiness probe returns 503 if database check fails."""
    with patch("app.db.database.check_db_health", new_callable=AsyncMock, return_value=False):
        response = await async_client.get("/health/ready")
        assert response.status_code == 503
        data = response.json()
        assert data["status"] == "degraded"
        assert data["services"]["database"] == "disconnected"


@pytest.mark.asyncio
async def test_readiness_endpoint_fails_when_redis_down(async_client: AsyncClient):
    """Readiness probe returns 503 if Redis check fails."""
    with patch("app.core.dependencies.check_redis_health", new_callable=AsyncMock, return_value=False):
        response = await async_client.get("/health/ready")
        assert response.status_code == 503
        data = response.json()
        assert data["status"] == "degraded"
        assert data["services"]["redis"] == "disconnected"


@pytest.mark.asyncio
async def test_deep_health_endpoint_contract(async_client: AsyncClient):
    """Deep system health returns 200 and checks all subsystems."""
    response = await async_client.get("/api/v1/health")
    assert response.status_code == 200
    payload = response.json()
    assert payload["success"] is True
    data = payload["data"]
    assert "status" in data
    assert "services" in data
    assert "database" in data["services"]
    assert "redis" in data["services"]


# ---------------------------------------------------------------------------
# Metrics Tests
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_prometheus_metrics_exposition(async_client: AsyncClient):
    """Prometheus exposition endpoint returns 200 text/plain with standard formats."""
    await async_client.get("/health/live")

    response = await async_client.get("/metrics")
    assert response.status_code == 200
    assert "text/plain" in response.headers.get("content-type", "")
    body = response.text

    assert "# HELP hums_http_requests_total" in body
    assert "# TYPE hums_http_requests_total counter"
    assert "hums_http_requests_total{" in body
    assert 'endpoint="/health/live"' in body


@pytest.mark.asyncio
async def test_json_metrics_summary(async_client: AsyncClient):
    """Internal JSON metrics endpoint returns summary counters and histograms."""
    await async_client.get("/health/live")

    response = await async_client.get("/api/v1/metrics")
    assert response.status_code == 200
    data = response.json()
    assert "metrics" in data
    metrics_data = data["metrics"]
    assert "http" in metrics_data
    assert "requests" in metrics_data["http"]
    assert "database" in metrics_data
    assert "celery" in metrics_data
    assert "playback" in metrics_data


# ---------------------------------------------------------------------------
# Client Telemetry Ingestion Tests
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_client_telemetry_batch_ingestion(async_client: AsyncClient):
    """Telemetry endpoint accepts client playback and error batches."""
    batch_payload = {
        "events": [
            {
                "event_type": "play_started",
                "track_type": "track",
                "platform": "ios",
                "app_version": "1.0.0",
            },
            {
                "event_type": "playback_error",
                "track_type": "track",
                "error_category": "buffer_underrun",
                "http_status": 504,
                "platform": "ios",
                "app_version": "1.0.0",
            },
        ],
        "errors": [
            {
                "error_type": "AudioPlayerError",
                "error_message": "Decoder failure on buffer underrun",
                "screen": "NowPlayingScreen",
                "platform": "ios",
                "app_version": "1.0.0",
            }
        ],
    }

    initial_playback_events = metrics_registry.playback_events_total.get(event_type="play_started", platform="ios")
    initial_playback_errors = metrics_registry.playback_errors_total.get(category="buffer_underrun", platform="ios")
    initial_runtime_errors = metrics_registry.client_runtime_errors_total.get(error_type="AudioPlayerError", platform="ios")

    response = await async_client.post("/api/v1/telemetry/events", json=batch_payload)
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["data"]["message"] == "Telemetry accepted"

    new_playback_events = metrics_registry.playback_events_total.get(event_type="play_started", platform="ios")
    new_playback_errors = metrics_registry.playback_errors_total.get(category="buffer_underrun", platform="ios")
    new_runtime_errors = metrics_registry.client_runtime_errors_total.get(error_type="AudioPlayerError", platform="ios")

    assert new_playback_events == initial_playback_events + 1
    assert new_playback_errors == initial_playback_errors + 1
    assert new_runtime_errors == initial_runtime_errors + 1


@pytest.mark.asyncio
async def test_client_telemetry_rejects_excessive_batch(async_client: AsyncClient):
    """Telemetry endpoint rejects batches that exceed max limit (DoS protection)."""
    oversized_events = [
        {"event_type": "play_started", "platform": "android"} for _ in range(60)
    ]
    response = await async_client.post(
        "/api/v1/telemetry/events", json={"events": oversized_events}
    )
    assert response.status_code == 422


# ---------------------------------------------------------------------------
# Sensitive Data Masking Tests
# ---------------------------------------------------------------------------

def test_sensitive_data_filter_redacts_auth_headers():
    """Verifies that Authorization Bearer tokens are masked in log records."""
    log_filter = SensitiveDataFilter()
    record = logging.LogRecord(
        name="test_logger",
        level=logging.INFO,
        pathname=__file__,
        lineno=10,
        msg="Handling request with header Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.signature and token",
        args=(),
        exc_info=None,
    )
    log_filter.filter(record)
    assert "Bearer [REDACTED]" in record.msg
    assert "eyJhbGciOiJIUzI1Ni" not in record.msg


def test_sensitive_data_filter_redacts_passwords():
    """Verifies that JSON password fields are masked in log records."""
    log_filter = SensitiveDataFilter()
    record = logging.LogRecord(
        name="test_logger",
        level=logging.INFO,
        pathname=__file__,
        lineno=20,
        msg='User registration attempt payload {"email": "user@example.com", "password": "SuperSecretPassword123!"}',
        args=(),
        exc_info=None,
    )
    log_filter.filter(record)
    assert '"password": "[REDACTED]"' in record.msg
    assert "SuperSecretPassword123!" not in record.msg


def test_sensitive_data_filter_redacts_signed_urls():
    """Verifies that AWS/S3 query signatures are masked."""
    log_filter = SensitiveDataFilter()
    record = logging.LogRecord(
        name="test_logger",
        level=logging.INFO,
        pathname=__file__,
        lineno=30,
        msg="Fetching signed audio: https://minio.hums.local/audio/123.mp3?X-Amz-Signature=abcdef0123456789&key=val",
        args=(),
        exc_info=None,
    )
    log_filter.filter(record)
    assert "X-Amz-Signature=[REDACTED]" in record.msg
    assert "abcdef0123456789" not in record.msg


def test_structured_json_formatter_metadata():
    """Verifies that StructuredJSONFormatter emits valid JSON with service, request_id, and timestamp."""
    formatter = StructuredJSONFormatter(service_name="hums-test", environment="test")
    set_request_id("req-trace-test-fmt")
    try:
        record = logging.LogRecord(
            name="test_logger",
            level=logging.WARNING,
            pathname=__file__,
            lineno=40,
            msg="Warning: high memory",
            args=(),
            exc_info=None,
        )
        formatted = formatter.format(record)
        data = json.loads(formatted)
        assert data["service"] == "hums-test"
        assert data["environment"] == "test"
        assert data["level"] == "WARNING"
        assert data["request_id"] == "req-trace-test-fmt"
        assert data["message"] == "Warning: high memory"
        assert "timestamp" in data
    finally:
        clear_request_id()


# ---------------------------------------------------------------------------
# Database Observability Tests
# ---------------------------------------------------------------------------

def test_database_pool_status():
    """Verifies that get_db_pool_status returns integer pool metrics."""
    pool_stats = get_db_pool_status()
    assert isinstance(pool_stats, dict)
    assert "pool_size" in pool_stats
    assert "checked_out" in pool_stats
    assert "overflow" in pool_stats
    assert "checked_in" in pool_stats


# ---------------------------------------------------------------------------
# Celery Failure Categorization Tests
# ---------------------------------------------------------------------------

def test_celery_task_failure_categorization():
    """Verifies that task failures are categorized into bounded low-cardinality classes."""
    assert categorize_task_failure(TimeoutError("Socket timed out")) == "timeout"
    assert categorize_task_failure(ConnectionError("Broker connection reset")) == "network_infrastructure"
    assert categorize_task_failure(RuntimeError("ffmpeg failed to decode")) == "media_codec_error"
    assert categorize_task_failure(PermissionError("Unauthorized file access")) == "authorization_error"
    assert categorize_task_failure(Exception("Unknown crash")) == "application_error"
