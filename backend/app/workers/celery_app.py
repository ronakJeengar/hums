from celery import Celery
from app.core.config import get_settings

settings = get_settings()

celery_app = Celery(
    "hums_worker",
    broker=settings.CELERY_BROKER_URL,
    backend=settings.CELERY_RESULT_BACKEND,
    include=["app.workers.audio_tasks"],
)

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
)

