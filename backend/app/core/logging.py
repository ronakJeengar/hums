import logging
import sys
import re
from typing import Any, Dict


class SensitiveDataFilter(logging.Filter):
    """
    Filter to mask sensitive information (passwords, tokens, API keys) from logs.
    """
    SENSITIVE_PATTERNS = [
        re.compile(r'(password|secret|token|api[_-]?key|authorization)["\']?\s*[:=]\s*["\']?([^"\'\s]+)', re.IGNORECASE),
        re.compile(r'(Bearer\s+)([A-Za-z0-9\-._~+/]+=*)', re.IGNORECASE),
    ]

    def filter(self, record: logging.LogRecord) -> bool:
        if isinstance(record.msg, str):
            for pattern in self.SENSITIVE_PATTERNS:
                record.msg = pattern.sub(r'\1: [REDACTED]', record.msg)
        return True


def setup_logging(log_level: str = "INFO") -> logging.Logger:
    """Configures structured application logging."""
    logger = logging.getLogger("hums")
    logger.setLevel(getattr(logging, log_level.upper(), logging.INFO))

    # Remove existing handlers to avoid duplicates
    if logger.hasHandlers():
        logger.handlers.clear()

    handler = logging.StreamHandler(sys.stdout)
    formatter = logging.Formatter(
        fmt="%(asctime)s [%(levelname)s] [%(name)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )
    handler.setFormatter(formatter)
    handler.addFilter(SensitiveDataFilter())
    logger.addHandler(handler)
    logger.propagate = False

    return logger
