#!/usr/bin/env bash
set -e

echo "=== Initializing Hums Development Environment ==="

if [ ! -f .env ]; then
  echo "Copying .env.example to .env..."
  cp .env.example .env
fi

echo "Starting Docker Compose services (Postgres, Redis, MinIO)..."
docker compose up -d

echo "Waiting for services to become healthy..."
docker compose ps

echo "Setup completed successfully!"
