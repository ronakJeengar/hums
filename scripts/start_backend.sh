#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HUMS_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Starting Hums Backend Service ==="
cd "$HUMS_ROOT/backend"

if [ -f ".venv/bin/activate" ]; then
  echo "Activating virtual environment (.venv)..."
  source .venv/bin/activate
fi

echo "Ensuring database migrations are up to date..."
alembic upgrade head

echo "Launching FastAPI server via Uvicorn on http://0.0.0.0:8001..."
uvicorn app.main:app --reload --host 0.0.0.0 --port 8001
