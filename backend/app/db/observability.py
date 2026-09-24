import logging
import time
from typing import Any, Dict, Optional
from sqlalchemy import event
from sqlalchemy.engine import Engine

from app.core.config import get_settings
from app.core.context import get_request_id
from app.core.metrics import metrics_registry

logger = logging.getLogger("hums.database.observability")
settings = get_settings()


def setup_database_observability(sync_engine: Engine) -> None:
    """
    Hooks execution event listeners into the SQLAlchemy sync engine to measure
    query latency, detect slow queries, and record query metrics.
    
    Guarantees:
    - Never logs bound parameters (prevents leaking passwords, tokens, or PII).
    - Fails open gracefully if telemetry collection errors.
    """

    @event.listens_for(sync_engine, "before_cursor_execute")
    def before_cursor_execute(conn, cursor, statement, parameters, context, executemany):
        conn.info.setdefault("query_start_time", []).append(time.perf_counter())

    @event.listens_for(sync_engine, "after_cursor_execute")
    def after_cursor_execute(conn, cursor, statement, parameters, context, executemany):
        try:
            start_times = conn.info.get("query_start_time", [])
            if not start_times:
                return
            start_time = start_times.pop()
            duration_seconds = time.perf_counter() - start_time
            duration_ms = duration_seconds * 1000.0

            # Determine query operation type (SELECT, INSERT, UPDATE, DELETE, etc.)
            operation = statement.strip().split()[0].upper() if statement else "UNKNOWN"

            is_slow = duration_ms >= settings.DB_SLOW_QUERY_MS

            # Record metric
            metrics_registry.record_db_query(
                operation=operation,
                duration_seconds=duration_seconds,
                is_slow=is_slow,
            )

            # Log slow query warning if threshold breached (without parameters!)
            if is_slow:
                # Truncate statement preview safely
                clean_stmt = " ".join(statement.split())[:150]
                logger.warning(
                    f"SLOW QUERY [{operation}] duration={duration_ms:.2f}ms "
                    f"threshold={settings.DB_SLOW_QUERY_MS}ms req_id={get_request_id()} "
                    f"stmt='{clean_stmt}...'"
                )
        except Exception as exc:
            # Defensive observability: query execution must never fail due to metrics
            logger.debug(f"Error in database observability after_cursor_execute: {exc}")


def get_db_pool_status(sync_engine: Optional[Engine] = None) -> Dict[str, Any]:
    """Inspects connection pool metrics safely."""
    try:
        if sync_engine is None:
            from app.db.database import engine
            sync_engine = engine.sync_engine
        pool = sync_engine.pool
        return {
            "pool_size": pool.size() if hasattr(pool, "size") else 0,
            "checked_in": pool.checkedin() if hasattr(pool, "checkedin") else 0,
            "checked_out": pool.checkedout() if hasattr(pool, "checkedout") else 0,
            "overflow": pool.overflow() if hasattr(pool, "overflow") else 0,
        }
    except Exception as exc:
        logger.debug(f"Could not retrieve pool status: {exc}")
        return {"status": "unavailable"}
