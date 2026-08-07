#!/usr/bin/env bash
# DSpark vLLM auto-start wrapper (idempotent, safe for systemd).
# Install to /usr/local/sbin/dspark-vllm-start.sh on the HEAD node.
# Replace <USER>, <REPO_PATH>, <IP_MGMT_B> with your real values first.
#
# Recovery logic (in order):
#   1. API healthy                     -> exit 0 (nothing to do)
#   2. worker container present        -> start the missing head container via
#                                        compose, then wait for the API
#   3. neither container present       -> run the upstream start script
set -uo pipefail

RUN_USER="<USER>"
REPO="<REPO_PATH>"
ENV_FILE="$REPO/.env.dspark"
COMPOSE_FILE="$REPO/docker-compose.dspark.yml"
PROJECT="deepseek-v4-flash"
API_URL="http://127.0.0.1:8888/v1/models"
HEAD_CONTAINER="$PROJECT-vllm-dspark-1"
WORKER_HOST_IP="<IP_MGMT_B>"
WAIT_ATTEMPTS=240   # 240 x 5s = up to 20 min for cold model load
WAIT_SECONDS=5

if [ "$(id -un)" != "$RUN_USER" ]; then
  exec runuser -u "$RUN_USER" -- "$0" "$@"
fi

if [ ! -x "$REPO/start-deepseek-v4-flash-dspark.sh" ]; then
  echo "start script missing: $REPO/start-deepseek-v4-flash-dspark.sh" >&2
  exit 1
fi

api_healthy() {
  curl -fsS --max-time 5 "$API_URL" >/dev/null 2>&1
}

wait_for_api() {
  echo "Waiting for the vLLM API (up to ${WAIT_ATTEMPTS}x${WAIT_SECONDS}s)..."
  for _ in $(seq 1 "$WAIT_ATTEMPTS"); do
    if api_healthy; then
      echo "dspark-vllm became healthy."
      return 0
    fi
    sleep "$WAIT_SECONDS"
  done
  echo "Timed out waiting for the API; will retry via systemd." >&2
  return 1
}

if api_healthy; then
  echo "dspark-vllm already healthy; skipping start."
  exit 0
fi

# Head container missing but worker present: bring the head up directly,
# then wait. (The upstream start script refuses when the worker container
# already exists, so we must not call it in this state.)
if ! docker ps -a --format "{{.Names}}" | grep -qx "$HEAD_CONTAINER"; then
  WORKER_CHECK="docker ps --format '{{.Names}}' | grep -qx '$HEAD_CONTAINER'"
  if ssh -o BatchMode=yes -o ConnectTimeout=10 "$RUN_USER@$WORKER_HOST_IP" "$WORKER_CHECK" >/dev/null 2>&1; then
    echo "Worker container present, head missing: starting head via compose..."
    cd "$REPO" || exit 1
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
    # shellcheck disable=SC2086
    env -u NODE_RANK -u HEADLESS COMPOSE_DISABLE_ENV_FILE=1 \
      WORKER_HOST="$WORKER_HOST" \
      MASTER_ADDR="$MASTER_ADDR" \
      MASTER_PORT="$MASTER_PORT" \
      NCCL_IB_HCA="$NCCL_IB_HCA" \
      NCCL_SOCKET_IFNAME="$NCCL_SOCKET_IFNAME" \
      NCCL_IB_GID_INDEX="${NCCL_IB_GID_INDEX:-}" \
      VLLM_HOST="${VLLM_HOST:-127.0.0.1}" \
      VLLM_PORT="${VLLM_PORT:-8888}" \
      VLLM_HOST_IP="${VLLM_HOST_IP:-$MASTER_ADDR}" \
      NODE_RANK=0 HEADLESS="" \
      docker compose -p "$PROJECT" --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d
    wait_for_api && exit 0 || exit 1
  fi
fi

echo "Starting DSpark vLLM service..."
cd "$REPO" || exit 1
exec ./start-deepseek-v4-flash-dspark.sh
