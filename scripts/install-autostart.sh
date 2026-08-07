#!/usr/bin/env bash
# One-shot installer for DSpark vLLM auto-start on a NEW pair of hosts.
# Run on the HEAD node (it also installs the worker unit via SSH).
#
# Replace <USER>, <IP_MGMT_A>, <IP_MGMT_B> below with your real values,
# and make sure the <placeholders> in the dspark-vllm-*.sh wrappers are
# replaced BEFORE running this script (see 09-ops.md).
set -euo pipefail

HEAD="${1:-<USER>@<IP_MGMT_A>}"
WORKER="${2:-<USER>@<IP_MGMT_B>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Installing head unit on $HEAD"
scp "$SCRIPT_DIR/dspark-vllm-start.sh" "$SCRIPT_DIR/dspark-vllm-stop.sh" "$HEAD:/tmp/"
ssh "$HEAD" "sudo install -m 0755 /tmp/dspark-vllm-start.sh /tmp/dspark-vllm-stop.sh /usr/local/sbin/ && sudo rm -f /tmp/dspark-vllm-start.sh /tmp/dspark-vllm-stop.sh"
scp "$SCRIPT_DIR/dspark-vllm.service" "$HEAD:/tmp/"
ssh "$HEAD" "sudo install -m 0644 /tmp/dspark-vllm.service /etc/systemd/system/ && sudo rm -f /tmp/dspark-vllm.service && sudo systemctl daemon-reload && sudo systemctl enable dspark-vllm.service"

echo "==> Installing worker unit on $WORKER"
scp "$SCRIPT_DIR/dspark-vllm-ensure.sh" "$WORKER:/tmp/"
ssh "$WORKER" "sudo install -m 0755 /tmp/dspark-vllm-ensure.sh /usr/local/sbin/ && sudo rm -f /tmp/dspark-vllm-ensure.sh"
scp "$SCRIPT_DIR/dspark-vllm-worker.service" "$WORKER:/tmp/"
ssh "$WORKER" "sudo install -m 0644 /tmp/dspark-vllm-worker.service /etc/systemd/system/ && sudo rm -f /tmp/dspark-vllm-worker.service && sudo systemctl daemon-reload && sudo systemctl enable dspark-vllm-worker.service"

echo "==> Done. Verify with:"
echo "    ssh $HEAD  'systemctl is-enabled dspark-vllm'"
echo "    ssh $WORKER 'systemctl is-enabled dspark-vllm-worker'"
