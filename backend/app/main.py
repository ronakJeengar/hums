from contextlib import asynccontextmanager
from typing import AsyncGenerator
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from app.api.router import api_router
from app.core.config import get_settings
from app.core.errors import register_error_handlers
from app.core.logging import setup_logging
from app.db.database import engine

settings = get_settings()
logger = setup_logging(
    log_level=settings.LOG_LEVEL,
    log_format=settings.LOG_FORMAT,
    environment=settings.APP_ENV,
)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Application lifespan context manager handling startup and shutdown events."""
    logger.info(f"Starting {settings.APP_NAME} in [{settings.APP_ENV}] environment")
    yield
    logger.info(f"Shutting down {settings.APP_NAME}...")
    await engine.dispose()
    logger.info("Database connection pool disposed.")


is_production = settings.APP_ENV.lower() == "production"

app = FastAPI(
    title=settings.APP_NAME,
    description="Hums — Independent High-Fidelity Audio Streaming & Podcast Platform API",
    version="1.0.0",
    docs_url=None if is_production else "/docs",
    redoc_url=None if is_production else "/redoc",
    openapi_url=None if is_production else "/openapi.json",
    lifespan=lifespan,
)

# Configure Cross-Origin Resource Sharing (CORS)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


from app.core.context import clear_request_id, set_request_id
from app.core.metrics import metrics_registry


@app.middleware("http")
async def security_headers_middleware(request: Request, call_next):
    """Enforces essential defensive HTTP security headers on all responses."""
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    if settings.APP_ENV.lower() == "production":
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    return response


@app.middleware("http")
async def request_observability_middleware(request: Request, call_next):
    """
    Manages request correlation (X-Request-ID), measures execution latency,
    records route-template low-cardinality metrics, and logs access events.
    """
    import time

    start_time = time.perf_counter()

    # Correlation ID
    raw_req_id = request.headers.get("X-Request-ID")
    req_id = set_request_id(raw_req_id)
    request.state.request_id = req_id

    try:
        response = await call_next(request)
        duration_seconds = time.perf_counter() - start_time
        duration_ms = duration_seconds * 1000.0

        # Attach headers
        response.headers["X-Request-ID"] = req_id
        response.headers["X-Process-Time"] = f"{duration_ms:.2f}ms"

        # Determine route template for low-cardinality metrics
        route = request.scope.get("route")
        route_template = route.path if route and hasattr(route, "path") else request.url.path

        # Record HTTP metrics
        metrics_registry.record_http_request(
            method=request.method,
            endpoint=route_template,
            status_code=response.status_code,
            duration_seconds=duration_seconds,
        )

        # Log request (suppress health/metrics probe noise in production unless error)
        is_probe = request.url.path in ("/health", "/health/live", "/metrics")
        if not is_probe or response.status_code >= 400 or settings.DEBUG:
            logger.info(
                f"{request.method} {request.url.path} [{response.status_code}] ({duration_ms:.2f}ms)"
            )

        return response
    except Exception as exc:
        duration_seconds = time.perf_counter() - start_time
        duration_ms = duration_seconds * 1000.0
        metrics_registry.record_http_request(
            method=request.method,
            endpoint=request.url.path,
            status_code=500,
            duration_seconds=duration_seconds,
        )
        logger.error(
            f"{request.method} {request.url.path} [FAILED] ({duration_ms:.2f}ms): {exc}"
        )
        raise
    finally:
        clear_request_id()


# Register centralized error & validation handlers
register_error_handlers(app)


# Root Liveness & Readiness Endpoints
@app.get(
    "/health",
    tags=["Health"],
    summary="Shallow liveness probe (backward compatible)",
)
async def root_health():
    """Liveness probe for orchestrators and load balancers."""
    return {
        "status": "healthy",
        "app": settings.APP_NAME,
        "environment": settings.APP_ENV,
    }


@app.get(
    "/health/live",
    tags=["Health"],
    summary="Process liveness probe",
)
async def liveness_probe():
    """Shallow process liveness probe."""
    return {
        "status": "alive",
        "app": settings.APP_NAME,
        "environment": settings.APP_ENV,
    }


@app.get(
    "/health/ready",
    tags=["Health"],
    summary="Application readiness probe",
)
async def readiness_probe():
    """Readiness probe verifying core dependencies (Postgres, Redis, Storage)."""
    from fastapi.responses import JSONResponse
    from app.db.database import check_db_health
    from app.core.dependencies import check_celery_broker_health, check_redis_health, check_storage_health

    db_ok = await check_db_health()
    redis_ok = await check_redis_health()
    celery_ok = await check_celery_broker_health()
    storage_ok = await check_storage_health()

    is_ready = db_ok and redis_ok
    status_code = 200 if is_ready else 503

    return JSONResponse(
        status_code=status_code,
        content={
            "status": "ready" if is_ready else "degraded",
            "app": settings.APP_NAME,
            "environment": settings.APP_ENV,
            "services": {
                "database": "connected" if db_ok else "disconnected",
                "redis": "connected" if redis_ok else "disconnected",
                "celery_broker": "connected" if celery_ok else "disconnected",
                "storage": "connected" if storage_ok else "disconnected",
            },
        },
    )


@app.get(
    "/metrics",
    tags=["Observability"],
    summary="Prometheus metrics exposition endpoint",
)
async def metrics_endpoint():
    """Exports metrics in standard Prometheus text format."""
    from fastapi.responses import PlainTextResponse
    return PlainTextResponse(
        content=metrics_registry.generate_prometheus_metrics(),
        media_type="text/plain; version=0.0.4; charset=utf-8",
    )


@app.get(
    "/api/v1/metrics",
    tags=["Observability"],
    summary="Structured JSON metrics summary",
)
async def metrics_json_endpoint():
    """Returns a structured JSON summary of metrics for monitoring dashboards."""
    return {
        "status": "healthy",
        "metrics": metrics_registry.get_summary(),
    }


# Mount Versioned API Routes under /api
app.include_router(api_router, prefix="/api")
