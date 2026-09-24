# Hums 🎵

> A modern, audio-first streaming and podcast mobile application engineered for acoustic warmth, high performance, and autonomous scale.

[![License: MIT](https://img.shields.io/badge/License-MIT-amber.svg)](https://opensource.org/licenses/MIT)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115+-009688.svg?logo=fastapi)](https://fastapi.tiangolo.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B.svg?logo=flutter)](https://flutter.dev)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791.svg?logo=postgresql)](https://www.postgresql.org)
[![Redis](https://img.shields.io/badge/Redis-7-DC382D.svg?logo=redis)](https://redis.io)

---

## 1. Overview

**Hums** is an independent, end-to-end audio streaming platform providing:
* High-fidelity audio playback with adaptive multi-bitrate streaming (HLS).
* Background audio processing (FFmpeg transcoding, waveform peak generation, metadata extraction).
* Direct creator audio and podcast episode publishing.
* Custom playlists, favorites, and listening history.
* Clean, warm, audio-centric mobile client built with Flutter and Riverpod.
* Architectural readiness for future Google Gemini-powered transcripts and smart discovery.

### Absolute Independence
Hums is completely self-contained. It operates with its own authentication system, databases, object storage buckets, and business logic without any dependencies on external social or video platforms.

---

## 2. Technology Stack

* **Mobile App:** Flutter (Dart), Riverpod (State Management), go_router (Declarative Routing), Dio (HTTP Client), Freezed (Immutable Models).
* **API Backend:** Python 3.11+, FastAPI (Async ASGI), Pydantic v2, SQLAlchemy 2.0 (Async), asyncpg, Alembic.
* **Database:** PostgreSQL 16.
* **Cache & Message Broker:** Redis 7.
* **Background Workers:** Celery + FFmpeg for asynchronous audio processing.
* **Object Storage:** S3-compatible storage (MinIO for local development; AWS S3 / Cloudflare R2 for production).
* **Delivery:** CDN-ready media distribution.

---

## 3. Repository Structure

```text
hums/
├── README.md               # Project overview and developer quickstart
├── .gitignore              # Source control exclusion rules
├── .env.example            # Environment variable template
├── docker-compose.yml      # Local development services (Postgres, Redis, MinIO)
│
├── backend/                # Python FastAPI Backend
│   ├── app/
│   │   ├── main.py         # Application entry point & lifespan
│   │   ├── core/           # Config, security, logging, error handlers
│   │   ├── db/             # SQLAlchemy async engine, session, base & models
│   │   ├── api/            # API routers (v1 endpoints, health checks)
│   │   ├── schemas/        # Pydantic v2 validation schemas
│   │   ├── services/       # Domain business logic
│   │   ├── repositories/   # Async database access layer
│   │   ├── workers/        # Celery application & audio tasks
│   │   └── utils/          # Storage client & audio helpers
│   ├── alembic/            # Database schema migrations
│   ├── tests/              # Pytest test suite (health, config, db)
│   ├── requirements.txt    # Python dependencies
│   └── Dockerfile          # Production backend container definition
│
├── mobile/                 # Flutter Cross-Platform Client
│   ├── lib/
│   │   ├── main.dart       # Flutter app entry point & ProviderScope
│   │   ├── core/           # Design system (colors, typography, theme), network
│   │   ├── routing/        # GoRouter navigation & routes
│   │   └── features/       # Feature-first Clean Architecture modules
│   ├── test/               # Flutter unit & widget tests
│   └── pubspec.yaml        # Flutter dependencies & assets
│
├── infra/                  # Infrastructure configurations
│   ├── docker/             # Container configs & scripts
│   └── nginx/              # Reverse proxy configuration
│
└── scripts/                # Developer helper scripts (setup, migrations)
```

---

## 4. Prerequisites

Ensure you have the following installed on your development machine:
* [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Docker & Docker Compose)
* [Python 3.11+](https://www.python.org/downloads/)
* [Flutter SDK 3.x+](https://docs.flutter.dev/get-started/install)
* Git

---

## 5. Quickstart & Local Setup

### Step 1: Clone and Configure Environment
```bash
git clone https://github.com/ronakJeengar/hums.git
cd hums

# Create local environment file from template
cp .env.example .env
```

### Step 2: Start Infrastructure (PostgreSQL, Redis, MinIO)
Start local supporting services in Docker:
```bash
docker compose up -d
```
Verify services are running:
* **PostgreSQL:** `localhost:5432` (`hums_db`)
* **Redis:** `localhost:6379`
* **MinIO API:** `http://localhost:9000`
* **MinIO Console:** `http://localhost:9001` (Credentials: `minioadmin` / `minioadmin`)

### Step 3: Backend Setup & Migrations
```bash
cd backend

# Create and activate a Python virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run database migrations
alembic upgrade head

# Start FastAPI server with live reload
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```
Interactive API documentation will be available at:
* Swagger UI: [http://localhost:8000/docs](http://localhost:8000/docs)
* ReDoc: [http://localhost:8000/redoc](http://localhost:8000/redoc)
* Health Check: [http://localhost:8000/api/v1/health](http://localhost:8000/api/v1/health)

### Step 4: Mobile App Setup (Flutter)
In a new terminal:
```bash
cd mobile

# Fetch Flutter dependencies
flutter pub get

# Run on connected device or emulator
flutter run
```

---

## 6. Running Tests

### Backend Tests
```bash
cd backend
pytest -v
```

### Flutter Tests
```bash
cd mobile
flutter test
```

### Performance Benchmarks
```bash
# Run Flutter widget rebuild benchmark
cd mobile
flutter test test/performance/rebuild_benchmark_test.dart
```

Comprehensive performance baselines, execution plans, and optimization reports are documented in:
* [`docs/performance/PERFORMANCE_BASELINE.md`](docs/performance/PERFORMANCE_BASELINE.md)
* [`docs/performance/PERFORMANCE_REPORT.md`](docs/performance/PERFORMANCE_REPORT.md)

---

## 7. Database Migrations (Alembic)

Whenever you add or update SQLAlchemy models:
```bash
cd backend

# Generate a new migration
alembic revision --autogenerate -m "describe changes"

# Apply migrations
alembic upgrade head

# Rollback one revision
alembic downgrade -1
```

---

## 8. Git Workflow

1. Always branch from `main`:
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/<feature-name>
   ```
2. Commit with conventional commit messages (`feat:`, `fix:`, `docs:`, `test:`).
3. Ensure all tests and linters pass before opening a Pull Request.
4. Merge via approved Pull Request into `main`.

---

## 9. Security & Hardening

Hums incorporates production-grade defensive security engineering:
* **Rate Limiting:** Atomic Redis sliding-window throttling on authentication, uploads, and creation endpoints with `Retry-After` headers.
* **Bounded Streams:** Early termination of oversized file uploads (`read_upload_file_bounded`) preventing memory starvation.
* **Strict Input Bounds:** Field-level character and array limits defending against algorithmic complexity and buffer overflows.
* **Security Headers:** Automatic enforcement of HSTS, `nosniff`, `DENY` framing, and strict referrer policies.
* **Container Isolation:** Docker backend executes as unprivileged `appuser` (UID 1000).
* **Secure Mobile Storage:** Hardware-backed token storage via Keychain / EncryptedSharedPreferences with release-mode log suppression.

Detailed documentation is available in [`docs/security/`](docs/security/):
* [Security Baseline](docs/security/SECURITY_BASELINE.md)
* [Security Report](docs/security/SECURITY_REPORT.md)
* [Security Checklist](docs/security/SECURITY_CHECKLIST.md)

---

## 10. Production Observability & Monitoring

Hums features an integrated, low-overhead observability layer providing full visibility across the distributed system:
* **Request Correlation:** Distributed tracing via `X-Request-ID` context propagation across all HTTP routes, background workers, and logs.
* **Structured Logging & Redaction:** Auto-switching structured JSON logging in production and human-readable text in development, with active masking of bearer tokens, passwords, database credentials, and presigned object storage URLs.
* **Low-Cardinality Metrics Registry:** High-performance in-memory registry exporting standard Prometheus exposition text (`GET /metrics`) and structured JSON summaries (`GET /api/v1/metrics`).
* **Multi-Tier Health Checks:** Shallow process liveness probe (`GET /health/live`), dependency-aware readiness probe (`GET /health/ready`), and deep subsystem status (`GET /api/v1/health`).
* **Database & Worker Telemetry:** Automatic SQLAlchemy query duration tracking, slow query alerting (`DB_SLOW_QUERY_MS`), connection pool monitoring, and Celery task lifecycle signal integration.
* **Mobile Client Telemetry:** Non-blocking batched ingestion (`POST /api/v1/telemetry/events`) for playback events, buffer stalls, and crash reporting with fail-open client behavior.

Comprehensive observability documentation:
* [Observability Architecture](docs/observability/OBSERVABILITY_ARCHITECTURE.md)
* [Alerting Rules & SLOs](docs/observability/ALERTS.md)
* [Dashboard Specifications](docs/observability/DASHBOARDS.md)
* [Operations Runbook](docs/observability/OPERATIONS_RUNBOOK.md)
* [Deployment Checklist](docs/observability/DEPLOYMENT_CHECKLIST.md)

