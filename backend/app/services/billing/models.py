from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional


@dataclass
class VerifiedTransaction:
    """Represents an authoritative purchase verification result from a store provider."""
    transaction_id: str
    product_id: str
    purchase_date: datetime
    status: str  # ACTIVE, CANCELED, EXPIRED, REVOKED, IN_GRACE_PERIOD
    original_transaction_id: Optional[str] = None
    expires_date: Optional[datetime] = None
    environment: str = "Production"  # Production or Sandbox
    cancel_at_period_end: bool = False
    grace_period_end: Optional[datetime] = None
    raw_payload: str = ""


@dataclass
class VerifiedWebhookPayload:
    """Represents an authenticated, decoded lifecycle event from a store webhook."""
    event_id: str
    event_type: str  # RENEWAL, CANCELLATION, EXPIRATION, REVOCATION, GRACE_PERIOD
    provider: str
    transaction: Optional[VerifiedTransaction] = None
    original_transaction_id: Optional[str] = None
    raw_payload: str = ""
