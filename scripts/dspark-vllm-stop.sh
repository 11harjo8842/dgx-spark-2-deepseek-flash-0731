#!/usr/bin/env bash
# DSpark vLLM stop wrapper (idempotent; stops head + worker containers).
# Install to /usr/local/sbin/dspark-vllm-stop.sh on the HEAD node.
# Replace <USER>, <REPO_PATH> with your real values first.
set -uo pipefail

RUN_USER="<USER>"
REPO="<REPO_PATH>"

if [ "$(id -un)" != "$RUN_USER" ]; then
  exec runuser -u "$RUN_USER" -- "$0" "$@"
fi

if [ ! -x "$REPO/stop-deepseek-v4-flash-dspark.sh" ]; then
  echo "stop script missing: $REPO/stop-deepseek-v4-flash-dspark.sh" >&2
  exit 1
fi

cd "$REPO" || exit 1
exec ./stop-deepseek-v4-flash-dspark.sh
