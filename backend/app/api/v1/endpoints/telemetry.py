import logging
from fastapi import APIRouter, status
from app.core.metrics import metrics_registry
from app.schemas.common import ApiResponse, MessageData
from app.schemas.telemetry import TelemetryBatchRequest

router = APIRouter(prefix="/telemetry", tags=["Telemetry & Observability"])
logger = logging.getLogger("hums.telemetry")


@router.post(
    "/events",
    response_model=ApiResponse[MessageData],
    status_code=status.HTTP_200_OK,
    summary="Ingest Batched Client Telemetry Events",
    description="Receives client playback events and non-sensitive error reports in batches.",
)
async def ingest_telemetry_events(payload: TelemetryBatchRequest) -> ApiResponse[MessageData]:
    # Record playback events into metrics
    for event in payload.events:
        clean_event = event.event_type.lower()[:50]
        error_cat = event.error_category[:50] if event.error_category else None
        platform = event.platform or "mobile"

        metrics_registry.record_playback_event(
            event_type=clean_event,
            error_category=error_cat,
            platform=platform,
        )

        if error_cat:
            logger.warning(
                f"Client playback error: event={clean_event} category={error_cat} "
                f"platform={platform} version={event.app_version}"
            )

    # Record client errors
    for err in payload.errors:
        metrics_registry.client_runtime_errors_total.inc(
            error_type=err.error_type[:50],
            platform=err.platform or "mobile",
        )
        logger.error(
            f"Client runtime error [{err.error_type}] screen={err.screen} "
            f"msg='{err.error_message}' platform={err.platform}"
        )

    return ApiResponse(data=MessageData(message="Telemetry accepted"))
