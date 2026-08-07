#!/usr/bin/env bash
# =============================================================================
# 复现前自检：在 head 上运行，检查双机环境是否满足部署前置条件。
# 用法：bash repro-preflight.sh <IP_MGMT_B>
# head 检查在本机直接执行；worker 检查通过 SSH。
# =============================================================================
set -u
WORKER="${1:?用法: bash repro-preflight.sh <IP_MGMT_B>}"
IMAGE="ghcr.io/anemll/dspark-vllm-gx10:0.1.1"
MODEL_DIR="$HOME/.cache/huggingface/models"
MODEL_NAME="DeepSeek-V4-Flash-0731"
FAIL=0

say()  { printf '[%s] %s\n' "$1" "$2"; }
ok()   { say OK   "$*"; }
bad()  { say FAIL "$*"; FAIL=1; }

echo "=== head: $(hostname) / worker: $WORKER ==="

# 1) 双方 SSH 免密
if ssh -o BatchMode=yes -o ConnectTimeout=8 "$WORKER" 'echo ok' >/dev/null 2>&1; then ok "SSH $WORKER"; else bad "SSH $WORKER 不通"; fi

# 2) 系统版本 / GPU / CUDA / Docker（head 本机执行，worker 走 SSH）
check_node() {
  local tag="$1" target="$2"
  local out
  if [ -n "$target" ]; then
    out=$(ssh -o BatchMode=yes -o ConnectTimeout=8 "$target" '
      printf "gpu=%s cuda=%s docker=%s sudo_nopasswd=%s" \
        "$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)" \
        "$(ls -d /usr/local/cuda*/bin/nvcc 2>/dev/null | head -1 >/dev/null && /usr/local/cuda*/bin/nvcc --version 2>/dev/null | grep release | sed "s/.*release //;s/,.*//" | head -1)" \
        "$(docker --version 2>/dev/null | awk "{print \$3}")" \
        "$(sudo -n true 2>/dev/null && echo yes || echo no)"' 2>/dev/null)
  else
    out=$(printf "gpu=%s cuda=%s docker=%s sudo_nopasswd=%s" \
      "$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)" \
      "$(ls -d /usr/local/cuda*/bin/nvcc 2>/dev/null | head -1 >/dev/null && for n in /usr/local/cuda*/bin/nvcc; do [ -x "$n" ] && "$n" --version 2>/dev/null | grep release | sed "s/.*release //;s/,.*//" | head -1 && break; done)" \
      "$(docker --version 2>/dev/null | awk '{print $3}')" \
      "$(sudo -n true 2>/dev/null && echo yes || echo no)")
  fi
  if [[ "$out" == *gpu=NVIDIA* && "$out" == *sudo_nopasswd=yes* ]]; then ok "$tag: $out"; else bad "$tag: $out"; fi
}
check_node "HEAD" ""
check_node "WORKER" "$WORKER"

# 3) 运行时镜像（双机）
check_image() {
  local tag="$1" target="$2"
  if [ -n "$target" ]; then
    if ssh -o BatchMode=yes -o ConnectTimeout=8 "$target" "docker image inspect '$IMAGE' >/dev/null 2>&1"; then ok "$tag 镜像存在"; else bad "$tag 缺镜像 $IMAGE"; fi
  else
    if docker image inspect "$IMAGE" >/dev/null 2>&1; then ok "$tag 镜像存在"; else bad "$tag 缺镜像 $IMAGE"; fi
  fi
}
check_image "HEAD" ""
check_image "WORKER" "$WORKER"

# 4) 模型缓存（双机）
check_model() {
  local tag="$1" target="$2" sz
  if [ -n "$target" ]; then
    sz=$(ssh -o BatchMode=yes -o ConnectTimeout=8 "$target" "du -sb '$MODEL_DIR/$MODEL_NAME' 2>/dev/null | cut -f1")
  else
    sz=$(du -sb "$MODEL_DIR/$MODEL_NAME" 2>/dev/null | cut -f1)
  fi
  if [ -n "$sz" ] && [ "$sz" -gt 160000000000 ]; then ok "$tag 模型缓存 $(awk -v x=$sz 'BEGIN{printf "%.1f GB", x/1e9}')"; else bad "$tag 模型缓存不足 ($sz)"; fi
}
check_model "HEAD" ""
check_model "WORKER" "$WORKER"

# 5) RoCE 链路（双机各自的有线口）
check_roce() {
  local tag="$1" target="$2" out
  if [ -n "$target" ]; then
    out=$(ssh -o BatchMode=yes -o ConnectTimeout=8 "$target" 'rdma link show 2>/dev/null | grep -c "state ACTIVE physical_state LINK_UP"')
  else
    out=$(rdma link show 2>/dev/null | grep -c "state ACTIVE physical_state LINK_UP")
  fi
  if [ "${out:-0}" -ge 1 ]; then ok "$tag RoCE ACTIVE ×$out"; else bad "$tag 无 ACTIVE RoCE 链路"; fi
}
check_roce "HEAD" ""
check_roce "WORKER" "$WORKER"

# 6) 8888 端口空闲（head 本机）
if ss -ltn "( sport = :8888 )" 2>/dev/null | tail -n +2 | grep -q .; then bad "HEAD 8888 已被占用"; else ok "HEAD 8888 空闲"; fi

echo
if [ "$FAIL" -eq 0 ]; then echo "=== 全部通过，可以开始部署 ==="; else echo "=== 存在 $FAIL 项失败，请先修复 ==="; exit 1; fi
