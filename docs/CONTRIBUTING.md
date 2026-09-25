# Contributing to Hums

Thank you for contributing to **Hums**, an independent audio streaming application.

To maintain architectural purity, system resilience, and code quality, please adhere to these guidelines.

---

## 1. Absolute Independence Rule

Hums is a completely standalone application. **Never**:
* Import or link shared databases, users, or auth from other platforms.
* Connect to external social or video streaming backend APIs.
* Assume shared caching or storage buckets.

---

## 2. Git & Branching Workflow

We adhere to a strict trunk-based / feature-branch workflow.

* **`main`:** Always production-ready and deployable. Never commit directly to `main`.
* **Feature Branches:** Branch off `main` using standard naming conventions:
  * `feature/<feature-name>`
  * `fix/<bug-description>`
  * `chore/<maintenance-task>`
  * `test/<test-suite>`

### Development Lifecycle
```text
main
  ↓
git checkout -b feature/<feature-name>
  ↓
Implement code + Unit/Integration Tests + Docs
  ↓
Run linters & test suites (all must pass)
  ↓
git commit (Conventional Commits)
  ↓
git push -u origin feature/<feature-name>
  ↓
Open Pull Request to `main`
  ↓
Review & Approval
  ↓
Merge to `main`
  ↓
Delete local and remote feature branch
```

---

## 3. Commit Message Conventions

We enforce [Conventional Commits](https://www.conventionalcommits.org/):

* `feat:` A new feature for the user or platform
* `fix:` A bug fix
* `docs:` Documentation updates only
* `test:` Adding or refactoring tests
* `refactor:` Code changes that neither fix a bug nor add a feature
* `chore:` Build process, tooling, or dependency updates

**Examples:**
* `feat: add user authentication endpoints`
* `test: verify audio transcoding job pipeline`
* `docs: update API specification for track upload`

---

## 4. Backend Standards (Python / FastAPI)

* **Python Version:** 3.11+ (Typed, asynchronous).
* **Code Formatting:** Clean PEP8 compliance.
* **Typing:** Strict type annotations everywhere (`pydantic.BaseModel`, `typing`).
* **Architecture Flow:**
  `Router -> Schema Validation -> Service -> Repository -> Database`.
* **Database Access:** SQLAlchemy 2.0 async sessions exclusively through repositories. No queries in route handlers.
* **Audio Transcoding:** Background processing via Celery + FFmpeg. **Never transcode in FastAPI request handlers.**
* **Error Handling:** Standardized error response envelope (`ApiResponse` / `ErrorResponse`).

---

## 5. Mobile Standards (Flutter / Dart)

* **Architecture:** Feature-first Clean Architecture (`data/`, `domain/`, `presentation/`).
* **State Management:** **Riverpod** is the sole approved state management library. Do not introduce Bloc, Provider, or GetX.
* **Routing:** Declarative navigation via **go_router**.
* **Networking:** Handled through centralized **Dio** client with custom interceptors.
* **Design System:** Use centralized design tokens (`AppColors`, `AppTypography`, `AppSpacing`, `AppTheme`). Never hardcode raw hex values or arbitrary paddings across screens.

---

## 6. Security Invariants

* Never commit `.env`, credentials, JWT secrets, private keys, or API tokens.
* All passwords must be hashed before database persistence (Argon2id/Bcrypt).
* Validate file headers and MIME types server-side for any media uploads.
* Enforce server-side authorization checks on all mutating operations.

---

## 7. Running Tests

Before submitting any Pull Request, ensure all tests pass:

### Backend
```bash
cd backend
pytest -v
```

### Mobile
```bash
cd mobile
flutter test
```
