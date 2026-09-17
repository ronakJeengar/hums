from fastapi import APIRouter, Response, status
from app.core.config import get_settings
from app.core.dependencies import check_redis_health
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

    db_status = "connected" if db_healthy else "disconnected"
    redis_status = "connected" if redis_healthy else "disconnected"

    is_overall_healthy = db_healthy and redis_healthy

    if not is_overall_healthy:
        raise ServiceUnavailableError(
            message="One or more core infrastructure services are degraded or unreachable",
            details={
                "services": {
                    "database": db_status,
                    "redis": redis_status,
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
            ),
        )
    )
