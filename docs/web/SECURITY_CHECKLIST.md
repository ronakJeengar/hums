# Hums Web Platform — Security Architecture & Checklist

## 1. Threat Model & Mitigations

### 1.1 Token Hijacking & Cross-Site Scripting (XSS)
- **Mitigation:** JWT Access and Refresh Tokens are never stored in `localStorage` or `sessionStorage`. All tokens reside in `HttpOnly`, `SameSite=Lax`, `Secure` (production) cookies managed exclusively by the Next.js BFF server layer. Browser scripts have zero access to raw JWT secrets.

### 1.2 Cross-Site Request Forgery (CSRF)
- **Mitigation:** SameSite cookie enforcement (`Lax`) combined with standard JSON body requirements (`Content-Type: application/json`) ensures cross-origin sites cannot trigger state-modifying actions.

### 1.3 Privilege Escalation & Direct Object References (IDOR)
- **Mitigation:**
  - Administrative endpoints enforce role checks (`require_admin_role`, `require_moderator_or_admin_role`) via FastAPI dependency injection. Client-side role claims are completely ignored.
  - Creator endpoints verify track ownership on all mutations (`update_track`, `retry_processing`, `update_profile`) in the database query. A creator cannot modify or view unpublished drafts of other creators.
  - Administrators cannot demote or suspend their own account to prevent accidental lockouts (`CANNOT_SUSPEND_SELF`, `CANNOT_DEMOTE_SELF`).

### 1.4 Accountability & Audit Logging
- **Mitigation:** All administrative actions (`USER_ACTIVATE`, `USER_SUSPEND`, `USER_ROLE_CHANGE`, `VERIFY_CREATOR`, `REVIEW_APPLICATION`, `MODERATE_TRACK`, `RESOLVE_REPORT`, `RETRY_TRACK_PROCESSING`) generate an immutable audit log entry in the `admin_audit_logs` table containing:
  - Actor ID & Actor Email
  - Action name
  - Target entity type & Target ID
  - Changed fields snapshot
  - Administrative justification reason
  - Client IP address & Timestamp

---

## 2. Security Verification Checklist

- [x] All database migrations reversible and executed via Alembic.
- [x] No database credentials or payment secrets exposed to frontend.
- [x] Passwords hashed with standard argon2/bcrypt schemes.
- [x] Sensitive tokens kept out of browser storage via HttpOnly cookies.
- [x] Strict role hierarchy enforced on both edge middleware and backend dependencies.
- [x] Rate limiting infrastructure preserved.
- [x] Immutable audit trail recorded for all staff actions.
- [x] SQL injection prevented via SQLAlchemy 2.0 parameterized queries.
