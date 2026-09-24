import datetime
import json
import logging
import re
import sys
from typing import Any, Dict

from app.core.context import get_request_id


class SensitiveDataFilter(logging.Filter):
    """
    Defensive filter to redact secrets, tokens, credentials, and PII from log records.
    """
    SENSITIVE_PATTERNS = [
        # Authorization header and bearer tokens
        re.compile(r'(Bearer\s+)([A-Za-z0-9\-._~+/]+=*)', re.IGNORECASE),
        re.compile(r'(authorization["\']?\s*[:=]\s*["\']?Bearer\s+)([^"\'\s]+)', re.IGNORECASE),
        # Passwords, tokens, secrets, API keys in JSON/queries
        re.compile(r'((?:password|secret|token|refresh_token|api[_-]?key|secret_key|access_token)["\']?\s*[:=]\s*["\']?)([^"\'\s,;&]+)', re.IGNORECASE),
        # Database connection strings with user:password@host
        re.compile(r'(postgres(?:ql)?(?:\+[a-z0-9]+)?://[^:]+:)([^@]+)(@)', re.IGNORECASE),
        # S3 pre-signed URL signatures
        re.compile(r'(X-Amz-Signature=)([a-f0-9]+)', re.IGNORECASE),
    ]

    def filter(self, record: logging.LogRecord) -> bool:
        try:
            if isinstance(record.msg, str):
                msg = record.msg
                for pattern in self.SENSITIVE_PATTERNS:
                    if "postgres" in pattern.pattern:
                        msg = pattern.sub(r'\1***\3', msg)
                    elif "X-Amz-Signature" in pattern.pattern:
                        msg = pattern.sub(r'\1[REDACTED]', msg)
                    else:
                        msg = pattern.sub(r'\1[REDACTED]', msg)
                record.msg = msg
        except Exception:
            # Defensive logging: filter must never break the logger
            pass
        return True


class StructuredJSONFormatter(logging.Formatter):
    """
    Standardized JSON log formatter for production log aggregation systems
    (Datadog, Elastic/Kibana, CloudWatch, Loki, Google Cloud Logging).
    """

    def __init__(self, service_name: str = "hums-api", environment: str = "development"):
        super().__init__()
        self.service_name = service_name
        self.environment = environment

    def format(self, record: logging.LogRecord) -> str:
        timestamp = datetime.datetime.fromtimestamp(
            record.created, tz=datetime.timezone.utc
        ).isoformat()

        log_data: Dict[str, Any] = {
            "timestamp": timestamp,
            "level": record.levelname,
            "logger": record.name,
            "service": self.service_name,
            "environment": self.environment,
            "request_id": getattr(record, "request_id", None) or get_request_id(),
            "message": record.getMessage(),
        }

        # Include structured extras if attached to record
        standard_attrs = {
            "name", "msg", "args", "levelname", "levelno", "pathname", "filename",
            "module", "exc_info", "exc_text", "stack_info", "lineno", "funcName",
            "created", "msecs", "relativeCreated", "thread", "threadName",
            "processName", "process", "message", "request_id"
        }
        extras = {k: v for k, v in record.__dict__.items() if k not in standard_attrs and not k.startswith("_")}
        if extras:
            log_data["extra"] = extras

        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)

        return json.dumps(log_data, default=str)


class StandardTextFormatter(logging.Formatter):
    """Clean human-readable formatter for local development with request ID correlation."""

    def format(self, record: logging.LogRecord) -> str:
        req_id = getattr(record, "request_id", None) or get_request_id()
        time_str = datetime.datetime.fromtimestamp(record.created).strftime("%Y-%m-%d %H:%M:%S")
        msg = record.getMessage()
        exc_str = f"\n{self.formatException(record.exc_info)}" if record.exc_info else ""
        return f"{time_str} [{record.levelname}] [{record.name}] [{req_id}] {msg}{exc_str}"


def setup_logging(
    log_level: str = "INFO",
    log_format: str = "auto",
    environment: str = "development",
) -> logging.Logger:
    """Configures structured or text application logging with sensitive data redaction."""
    logger = logging.getLogger("hums")
    logger.setLevel(getattr(logging, log_level.upper(), logging.INFO))

    if logger.hasHandlers():
        logger.handlers.clear()

    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(getattr(logging, log_level.upper(), logging.INFO))
    handler.addFilter(SensitiveDataFilter())

    # Determine formatter
    use_json = log_format == "json" or (log_format == "auto" and environment.lower() == "production")
    if use_json:
        handler.setFormatter(StructuredJSONFormatter(environment=environment))
    else:
        handler.setFormatter(StandardTextFormatter())

    logger.addHandler(handler)
    logger.propagate = False

    return logger
