from celery import Celery

from app.core.config import get_settings

settings = get_settings()

celery_app = Celery(
    "hums_worker",
    broker=settings.CELERY_BROKER_URL,
    backend=settings.CELERY_RESULT_BACKEND,
    include=["app.workers.audio_tasks"],
)

# Connect observability signals
from app.workers import observability  # noqa: F401

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_time_limit=3600,  # 1 hour maximum for long transcoding tasks
    worker_prefetch_multiplier=1,  # Prevent worker from hoarding tasks
    task_acks_late=True,  # Acknowledge task only upon completion
    task_reject_on_worker_lost=True,
    result_expires=86400,  # 24-hour TTL for results in Redis DB 2 to prevent unbounded storage leak
    broker_transport_options={
        "visibility_timeout": 43200
    },  # 12-hour visibility timeout for long transcode jobs
)
