#!/bin/bash
# 开机自恢复：重启后自动续传模型、补拉镜像（配合 crontab @reboot 使用）
# 用法：chmod +x resume-downloads.sh
#       (crontab -l 2>/dev/null | grep -v resume-downloads.sh; echo "@reboot $HOME/resume-downloads.sh") | crontab -
LOG=$HOME/resume-downloads.log
exec >> "$LOG" 2>&1
echo "=== resume-downloads $(date) ==="
sleep 45
# 续传模型（若尚未全部下载完成且进程未在运行）
if ! grep -qE "ALL_DOWNLOADED|STILL_PENDING" $HOME/dsv4-chunkdl.log 2>/dev/null; then
  pgrep -f "dsv4-chunkdl[.]py" >/dev/null || setsid env -u http_proxy -u https_proxy -u all_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY $HOME/hf-venv/bin/python $HOME/dsv4-chunkdl.py >> $HOME/dsv4-chunkdl.log 2>&1 < /dev/null &
fi
# 补拉运行时镜像（若缺失）
if ! docker image inspect ghcr.io/anemll/dspark-vllm-gx10:0.1.1 >/dev/null 2>&1; then
  setsid docker pull ghcr.nju.edu.cn/anemll/dspark-vllm-gx10:0.1.1 >> $HOME/docker-pull.log 2>&1 < /dev/null &
fi
