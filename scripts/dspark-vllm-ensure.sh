#!/usr/bin/env bash
# Ensure the DSpark vLLM worker container exists and is running.
# Install to /usr/local/sbin/dspark-vllm-ensure.sh on the WORKER node.
# Used by dspark-vllm-worker.service on boot (worker node only).
# Replace <USER>, <REPO_PATH> with your real values first.
set -uo pipefail

PROJECT="deepseek-v4-flash"
SERVICE="vllm-dspark"
REPO="<REPO_PATH>"
RUN_USER="<USER>"

if [ "$(id -un)" != "$RUN_USER" ]; then
  exec runuser -u "$RUN_USER" -- "$0" "$@"
fi

CONTAINER="$PROJECT-$SERVICE-1"
if docker ps --format "{{.Names}}" | grep -qx "$CONTAINER"; then
  echo "worker container $CONTAINER already running."
  exit 0
fi

if [ ! -f "$REPO/docker-compose.dspark.yml" ] || [ ! -f "$REPO/.env.dspark" ]; then
  echo "worker compose/env missing in $REPO" >&2
  exit 1
fi

echo "Starting worker container $CONTAINER..."
cd "$REPO" || exit 1
NODE_RANK=1 HEADLESS=1 VLLM_HOST_IP="${VLLM_HOST_IP:-}" \
  COMPOSE_DISABLE_ENV_FILE=1 \
  docker compose -p "$PROJECT" --env-file .env.dspark -f docker-compose.dspark.yml up -d "$SERVICE"
