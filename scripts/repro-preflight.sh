#!/usr/bin/env bash
# =============================================================================
# 复现前自检：在 head 上运行，检查双机环境是否满足部署前置条件。
# 用法：bash repro-preflight.sh <IP_MGMT_B>
# =============================================================================
set -u
WORKER="${1:?用法: bash repro-preflight.sh <IP_MGMT_B>}"
HEAD_MGMT="$(hostname -I | awk '{print $1}')"
IMAGE="ghcr.io/anemll/dspark-vllm-gx10:0.1.1"
MODEL_DIR="$HOME/.cache/huggingface/models"
MODEL_NAME="DeepSeek-V4-Flash-0731"
FAIL=0

say()  { printf '[%s] %s\n' "$1" "$2"; }
ok()   { say OK   "$*"; }
bad()  { say FAIL "$*"; FAIL=1; }

echo "=== head: $HEAD_MGMT / worker: $WORKER ==="

# 1) 双方 SSH 免密
if ssh -o BatchMode=yes -o ConnectTimeout=8 "$WORKER" 'echo ok' >/dev/null 2>&1; then ok "SSH $WORKER"; else bad "SSH $WORKER 不通"; fi

# 2) 系统版本 / GPU / CUDA / Docker
for h in "" "$WORKER"; do
  tag=$([ -z "$h" ] && echo "HEAD" || echo "WORKER")
  out=$(ssh -o BatchMode=yes -o ConnectTimeout=8 ${h:+$h} '
    printf "gpu=%s cuda=%s docker=%s sudo_nopasswd=%s" \
      "$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)" \
      "$(nvcc --version 2>/dev/null | grep release | sed "s/.*release //;s/,.*//")" \
      "$(docker --version 2>/dev/null | awk "{print \$3}")" \
      "$(sudo -n true 2>/dev/null && echo yes || echo no)"' 2>/dev/null)
  if [[ "$out" == *gpu=NVIDIA* && "$out" == *sudo_nopasswd=yes* ]]; then ok "$tag: $out"; else bad "$tag: $out"; fi
done

# 3) 运行时镜像（双机）
for h in "" "$WORKER"; do
  tag=$([ -z "$h" ] && echo "HEAD" || echo "WORKER")
  if ssh -o BatchMode=yes -o ConnectTimeout=8 ${h:+$h} "docker image inspect '$IMAGE' >/dev/null 2>&1"; then ok "$tag 镜像存在"; else bad "$tag 缺镜像 $IMAGE"; fi
done

# 4) 模型缓存（双机）
for h in "" "$WORKER"; do
  tag=$([ -z "$h" ] && echo "HEAD" || echo "WORKER")
  sz=$(ssh -o BatchMode=yes -o ConnectTimeout=8 ${h:+$h} "du -sb '$MODEL_DIR/$MODEL_NAME' 2>/dev/null | cut -f1")
  if [ -n "$sz" ] && [ "$sz" -gt 160000000000 ]; then ok "$tag 模型缓存 $(awk -v x=$sz 'BEGIN{printf "%.1f GB", x/1e9}')"; else bad "$tag 模型缓存不足 ($sz)"; fi
done

# 5) RoCE 链路（双机各自的有线口）
for h in "" "$WORKER"; do
  tag=$([ -z "$h" ] && echo "HEAD" || echo "WORKER")
  out=$(ssh -o BatchMode=yes -o ConnectTimeout=8 ${h:+$h} 'rdma link show 2>/dev/null | grep -c "state ACTIVE physical_state LINK_UP"')
  if [ "${out:-0}" -ge 1 ]; then ok "$tag RoCE ACTIVE ×$out"; else bad "$tag 无 ACTIVE RoCE 链路"; fi
done

# 6) 8888 端口空闲（head）
if ssh -o BatchMode=yes -o ConnectTimeout=8 "" 'ss -ltn "( sport = :8888 )" | tail -n +2 | grep -q .' 2>/dev/null; then bad "HEAD 8888 已被占用"; else ok "HEAD 8888 空闲"; fi

echo
if [ "$FAIL" -eq 0 ]; then echo "=== 全部通过，可以开始部署 ==="; else echo "=== 存在 $FAIL 项失败，请先修复 ==="; exit 1; fi

