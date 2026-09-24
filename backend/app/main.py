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
logger = setup_logging(settings.LOG_LEVEL)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Application lifespan context manager handling startup and shutdown events."""
    logger.info(f"Starting {settings.APP_NAME} in [{settings.APP_ENV}] environment")
    yield
    logger.info(f"Shutting down {settings.APP_NAME}...")
    await engine.dispose()
    logger.info("Database connection pool disposed.")


app = FastAPI(
    title=settings.APP_NAME,
    description="Hums — Independent High-Fidelity Audio Streaming & Podcast Platform API",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
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


@app.middleware("http")
async def log_requests_middleware(request: Request, call_next):
    """Measures request execution duration, attaches X-Process-Time header, and logs structured latency."""
    import time

    start_time = time.perf_counter()
    method = request.method
    path = request.url.path

    try:
        response = await call_next(request)
        duration_ms = (time.perf_counter() - start_time) * 1000
        response.headers["X-Process-Time"] = f"{duration_ms:.2f}ms"

        # Avoid spamming logs for frequent shallow health probes unless in debug mode
        if path != "/health" or settings.DEBUG:
            logger.info(
                f"{method} {path} [{response.status_code}] ({duration_ms:.2f}ms)"
            )
        return response
    except Exception as exc:
        duration_ms = (time.perf_counter() - start_time) * 1000
        logger.error(f"{method} {path} [FAILED] ({duration_ms:.2f}ms): {exc}")
        raise


# Register centralized error & validation handlers
register_error_handlers(app)


# Root Liveness Endpoint
@app.get(
    "/health",
    tags=["Health"],
    summary="Shallow liveness probe",
)
async def root_health():
    """Liveness probe for orchestrators and load balancers."""
    return {
        "status": "healthy",
        "app": settings.APP_NAME,
        "environment": settings.APP_ENV,
    }


# Mount Versioned API Routes under /api
app.include_router(api_router, prefix="/api")
