import contextvars
import uuid
import re
from typing import Optional

# Context variable holding the unique correlation ID for the current request
_request_id_ctx_var: contextvars.ContextVar[Optional[str]] = contextvars.ContextVar(
    "request_id", default=None
)

# Safe pattern for incoming client-provided X-Request-ID (alphanumeric, hyphens, underscores up to 64 chars)
_SAFE_REQUEST_ID_REGEX = re.compile(r"^[a-zA-Z0-9_\-]{8,64}$")


def get_request_id() -> str:
    """Returns the current request correlation ID or generates a fallback."""
    req_id = _request_id_ctx_var.get()
    return req_id or "system"


def set_request_id(req_id: Optional[str]) -> str:
    """
    Validates or generates a clean request ID and stores it in the context variable.
    If the provided ID is invalid or absent, a fresh UUID4 string is generated.
    """
    if req_id and _SAFE_REQUEST_ID_REGEX.match(req_id.strip()):
        clean_id = req_id.strip()
    else:
        clean_id = str(uuid.uuid4())

    _request_id_ctx_var.set(clean_id)
    return clean_id


def clear_request_id() -> None:
    """Clears the request ID context variable."""
    _request_id_ctx_var.set(None)
