from celery import Celery
from app.core.config import get_settings

settings = get_settings()

celery_app = Celery(
    "hums_worker",
    broker=settings.REDIS_URL,
    backend=settings.REDIS_URL,
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
)
