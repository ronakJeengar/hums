from fastapi import APIRouter, Response, status
from app.core.config import get_settings
from app.core.dependencies import check_celery_broker_health, check_redis_health, check_storage_health
from app.core.errors import ServiceUnavailableError
from app.db.database import check_db_health
from app.schemas.common import ApiResponse, HealthData, HealthServiceStatus

router = APIRouter(tags=["Health"])
settings = get_settings()


@router.get(
    "/health",
    response_model=ApiResponse[HealthData],
    summary="Deep System Health Check",
    description="Validates active connectivity to PostgreSQL database and Redis cluster.",
)
async def check_system_health(response: Response) -> ApiResponse[HealthData]:
    db_healthy = await check_db_health()
    redis_healthy = await check_redis_health()
    celery_healthy = await check_celery_broker_health()
    storage_healthy = await check_storage_health()

    db_status = "connected" if db_healthy else "disconnected"
    redis_status = "connected" if redis_healthy else "disconnected"
    celery_status = "connected" if celery_healthy else "disconnected"
    storage_status = "connected" if storage_healthy else "disconnected"

    # Core dependencies required for general request serving
    is_overall_healthy = db_healthy and redis_healthy

    if not is_overall_healthy:
        raise ServiceUnavailableError(
            message="One or more core infrastructure services are degraded or unreachable",
            details={
                "services": {
                    "database": db_status,
                    "redis": redis_status,
                    "celery_broker": celery_status,
                    "storage": storage_status,
                }
            }
        )

    return ApiResponse(
        data=HealthData(
            status="healthy",
            version="1.0.0",
            environment=settings.APP_ENV,
            services=HealthServiceStatus(
                database=db_status,
                redis=redis_status,
                celery_broker=celery_status,
                storage=storage_status,
            ),
        )
    )


@router.get(
    "/health/live",
    summary="Process Liveness Probe",
    description="Shallow probe verifying that the application process is running.",
)
async def health_live():
    """Liveness probe. Never fails due to database or external dependencies."""
    return {
        "status": "alive",
        "service": settings.APP_NAME,
        "environment": settings.APP_ENV,
    }


@router.get(
    "/health/ready",
    summary="Application Readiness Probe",
    description="Deep probe verifying that core dependencies (Postgres, Redis) can serve traffic.",
)
async def health_ready():
    """Readiness probe verifying database and cache availability."""
    db_healthy = await check_db_health()
    redis_healthy = await check_redis_health()

    if not (db_healthy and redis_healthy):
        raise ServiceUnavailableError(
            message="Application is not ready to serve traffic",
            details={
                "database": "connected" if db_healthy else "disconnected",
                "redis": "connected" if redis_healthy else "disconnected",
            }
        )

    return {
        "status": "ready",
        "service": settings.APP_NAME,
        "environment": settings.APP_ENV,
        "dependencies": {
            "database": "connected",
            "redis": "connected",
        }
    }
