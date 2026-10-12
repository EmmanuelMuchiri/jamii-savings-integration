#!/usr/bin/env bash
# Whole platform, end to end, in one command:
#   1. mock backends, H2, MI, API Manager (WSO2 images built from the zips in dist/)
#   2. apim-init: publishes tier, APIs, API Product, demo app, then runs the gateway checks
# Usage: scripts/up.sh
set -euo pipefail
cd "$(dirname "$0")/.."
# Every service belongs to a profile; default to the core stack if .env does not choose one
export COMPOSE_PROFILES="${COMPOSE_PROFILES:-$(grep -E '^COMPOSE_PROFILES=' .env 2>/dev/null | cut -d= -f2)}"
export COMPOSE_PROFILES="${COMPOSE_PROFILES:-core}"
echo "== compose profiles: $COMPOSE_PROFILES"

echo "== building and starting mock backends, H2, MI, API Manager and apim-init"
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
