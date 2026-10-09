#!/usr/bin/env bash
# Whole platform, end to end, in one command:
#   1. mock backends (separate repo; creates the shared network)       skipped if already running
#   2. H2, MI, API Manager (built from the WSO2 zips in dist/)
#   3. apim-init: publishes tier, APIs, API Product, demo app, then runs the gateway checks
# Usage: scripts/up.sh            MOCKS_DIR=../jamii-mock-backends by default
set -euo pipefail
cd "$(dirname "$0")/.."
MOCKS_DIR="${MOCKS_DIR:-../jamii-mock-backends}"
# Every service belongs to a profile; default to the core stack if .env does not choose one
export COMPOSE_PROFILES="${COMPOSE_PROFILES:-$(grep -E '^COMPOSE_PROFILES=' .env 2>/dev/null | cut -d= -f2)}"
export COMPOSE_PROFILES="${COMPOSE_PROFILES:-core}"
echo "== compose profiles: $COMPOSE_PROFILES"

if docker network inspect jamii-shared >/dev/null 2>&1 && docker ps --format '{{.Names}}' | grep -qx jamii-mock-backends; then
  echo "== mock backends already running"
elif [[ -f "$MOCKS_DIR/docker-compose.yml" ]]; then
  echo "== starting mock backends from $MOCKS_DIR"
  (cd "$MOCKS_DIR" && docker compose up -d --build)
else
  echo "ERROR: mock backends not running and not found at $MOCKS_DIR"
  echo "       Start them from their repo (docker compose up -d --build) or set MOCKS_DIR."
  exit 1
fi

echo "== building and starting H2, MI, API Manager and apim-init"
docker compose up -d --build

echo "== publishing APIs (following apim-init; API Manager takes 2-3 minutes on first start)"
docker compose logs -f apim-init &
LOGS=$!
CODE=$(docker wait "$(docker compose ps -a -q apim-init)")
sleep 1; kill $LOGS 2>/dev/null || true
echo
if [[ $CODE == 0 ]]; then
  echo "== ready"
  echo "   Developer Portal  https://localhost:9443/devportal"
  echo "   Publisher         https://localhost:9443/publisher"
  echo "   Gateway           https://localhost:8243"
  echo "   Demo credentials  .apim-demo.env"
else
  echo "== apim-init failed (exit $CODE). Full log: docker compose logs apim-init"
fi
exit "$CODE"
