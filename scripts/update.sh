#!/usr/bin/env bash
# Pulls latest docker images and restarts the compose stack.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="$(dirname "$SCRIPT_DIR")"

cd "$COMPOSE_DIR"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Pulling latest images..."
docker compose pull

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Restarting stack..."
docker compose up -d --remove-orphans

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Update complete."
