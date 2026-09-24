import logging
import time
from typing import Optional
from celery.signals import task_failure, task_postrun, task_prerun, task_retry
import redis.asyncio as aioredis

from app.core.config import get_settings
from app.core.metrics import metrics_registry

logger = logging.getLogger("hums.workers.observability")
settings = get_settings()


def categorize_task_failure(exc: Exception) -> str:
    """Categorizes exception into controlled low-cardinality failure categories."""
    msg = str(exc).lower()
    exc_type = type(exc).__name__.lower()

    if "timeout" in msg or "timeout" in exc_type:
        return "timeout"
    elif "connection" in msg or "network" in msg or "broker" in msg:
        return "network_infrastructure"
    elif "codec" in msg or "ffmpeg" in msg or "format" in msg or "decode" in msg:
        return "media_codec_error"
    elif "s3" in msg or "minio" in msg or "storage" in msg or "boto" in msg:
        return "storage_error"
    elif "permission" in msg or "unauthorized" in msg:
        return "authorization_error"
    return "application_error"


@task_prerun.connect
def on_task_prerun(task_id, task, *args, **kwargs):
    """Fired immediately before a task begins execution."""
    task.request.task_start_time = time.perf_counter()
    metrics_registry.record_celery_task(task_name=task.name, status="started")
    logger.info(f"[TASK_START] task={task.name} task_id={task_id}")


@task_postrun.connect
def on_task_postrun(task_id, task, retval, state, *args, **kwargs):
    """Fired immediately after a task finishes execution."""
    start_time = getattr(task.request, "task_start_time", None)
    duration_seconds = time.perf_counter() - start_time if start_time else 0.0
    duration_ms = duration_seconds * 1000.0

    metrics_registry.record_celery_task(
        task_name=task.name,
        status=state or "complete",
        duration_seconds=duration_seconds,
    )

    if task.name == "app.workers.audio_tasks.process_audio_track" and state == "SUCCESS":
        metrics_registry.record_audio_transcode(success=True, duration_seconds=duration_seconds)

    logger.info(
        f"[TASK_COMPLETE] task={task.name} task_id={task_id} status={state} "
        f"duration={duration_ms:.2f}ms"
    )


@task_failure.connect
def on_task_failure(task_id, exception, *args, **kwargs):
    """Fired when a task raises an unhandled exception."""
    task = kwargs.get("sender")
    task_name = task.name if task else "unknown_task"
    category = categorize_task_failure(exception)

    metrics_registry.record_celery_task(task_name=task_name, status="failure")

    if task_name == "app.workers.audio_tasks.process_audio_track":
        metrics_registry.record_audio_transcode(
            success=False,
            duration_seconds=0.0,
            failure_category=category,
        )

    logger.error(
        f"[TASK_FAILURE] task={task_name} task_id={task_id} "
        f"category={category} exc={type(exception).__name__}: {exception}"
    )


@task_retry.connect
def on_task_retry(request, reason, *args, **kwargs):
    """Fired when a task is scheduled for retry."""
    task_name = getattr(request, "task", "unknown_task")
    metrics_registry.record_celery_task(task_name=task_name, status="retry")
    logger.warning(
        f"[TASK_RETRY] task={task_name} task_id={request.id} "
        f"retries={getattr(request, 'retries', 0)} reason='{reason}'"
    )


async def get_celery_queue_depth(queue_name: str = "celery") -> int:
    """Returns the pending task count in the Redis broker queue."""
    try:
        client = aioredis.from_url(settings.CELERY_BROKER_URL, socket_timeout=2.0)
        async with client:
            depth = await client.llen(queue_name)
            return int(depth)
    except Exception as exc:
        logger.debug(f"Could not retrieve Celery queue depth: {exc}")
        return -1
