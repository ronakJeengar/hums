# Hums Web Platform — Role Permissions & Access Control

## 1. Role Hierarchy

Hums defines four distinct platform roles:

```
[admin] (Level 40)
   └── [moderator] (Level 30)
          └── [creator] (Level 20)
                 └── [listener] (Level 10)
```

---

## 2. Permissions Matrix

| Capability / Action | `listener` | `creator` | `moderator` | `admin` |
| :--- | :---: | :---: | :---: | :---: |
| Access Public Streaming & Mobile App | Yes | Yes | Yes | Yes |
| Submit Creator Program Application | Yes | — | — | — |
| File Content Violation Report | Yes | Yes | Yes | Yes |
| Access Creator Studio (`/studio/*`) | No | **Yes** | No | **Yes** |
| Upload & Transcode Tracks | No | **Yes** | No | **Yes** |
| Edit Own Track Metadata | No | **Yes** | No | **Yes** |
| View Own Listening Analytics | No | **Yes** | No | **Yes** |
| Access Admin Panel (`/admin/*`) | No | No | **Yes** | **Yes** |
| Review Creator Applications | No | No | **Yes** | **Yes** |
| Review & Resolve Violation Reports | No | No | **Yes** | **Yes** |
| Moderate / Takedown Tracks | No | No | **Yes** | **Yes** |
| Retry Transcode Jobs | No | No | **Yes** | **Yes** |
| View User Accounts Directory | No | No | **Yes** | **Yes** |
| Suspend / Reactivate User Accounts | No | No | No | **Yes** |
| Change User Platform Role | No | No | No | **Yes** |
| Toggle Artist Verified Badges | No | No | No | **Yes** |
| View Operations & Infrastructure Health | No | No | No | **Yes** |
| Search Immutable Audit Logs | No | No | No | **Yes** |

---

## 3. Enforcement Layers

1. **Next.js Edge Middleware (`middleware.ts`):** Checks `hums_user_role` cookie before page rendering and redirects unauthorized users to their permitted workspace.
2. **FastAPI Route Dependencies (`dependencies.py`):**
   - `require_admin_role`: Rejects with `403 Forbidden` unless role is `admin`.
   - `require_moderator_or_admin_role`: Rejects with `403 Forbidden` unless role is `moderator` or `admin`.
   - `require_creator_role`: Rejects with `403 Forbidden` unless role is `creator` or `admin` or user has a verified `Creator` entity.
