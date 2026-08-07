# 09 运维、自恢复与故障排查

## 9.1 日常命令

```bash
cd ~/DeepSeek-v4-Flash-DSpark-2x-DGX-Spark
./status-deepseek-v4-flash-dspark.sh   # 双机容器状态
./logs-deepseek-v4-flash-dspark.sh     # 双机日志
./smoke-deepseek-v4-flash-dspark.sh    # 冒烟
./stop-deepseek-v4-flash-dspark.sh     # 停止（先停 head 后停 worker 由脚本处理）
docker compose --env-file .env.dspark -f docker-compose.dspark.yml ps
```

## 9.2 开机自恢复（下载类任务）

```bash
chmod +x ~/resume-downloads.sh
( crontab -l 2>/dev/null | grep -v resume-downloads.sh; \
  echo "@reboot $HOME/resume-downloads.sh" ) | crontab -
```

重启后自动：续传未完成的模型下载、补拉缺失的镜像。所有长任务都应
`nohup setsid ... < /dev/null &` 脱离 SSH 会话（PPID=1、TTY=? 即成功）。

## 9.3 内核与内存加固

```bash
echo vm.compaction_proactiveness=0 | sudo tee /etc/sysctl.d/99-dsv4.conf
sudo sysctl -w vm.compaction_proactiveness=0
```

社区记录过：高负载下 `kcompactd` soft-lockup + NVIDIA `mstflint` 轮询触发内核 NULL-deref，
导致整机重启；`vm.compaction_proactiveness=0` 是防御手段。另注意 `mlx5_core insufficient power 27W`
日志是 GB10 集成 CX-7 的正常现象，不是故障。

## 9.4 常见故障排查表

| 现象 | 原因 | 处理 |
|---|---|---|
| 集群测速 25G | 网络计划未生效 | 直接重启两台（线保持插着）后 Run Test Again；重启才是关键，反复插拔线缆无效 |
| `nvidia-smi` failed | 升级后未重启 | 重启 |
| NCCL `ibv_modify_qp` / GID 错误 | RoCEv2 GID 索引漂移 | 保持 `NCCL_IB_GID_AUTO=1`；或按 05 章逐台查 GID 表 |
| mpirun 卡住 | SSH 免密/主机密钥问题 | 先最小 `mpirun hostname` 验证 |
| 模型下载 hash-fail | 下载器旧 bug / 脏 sidecar | 用本包脚本（已修复）；删除 `*.chunks.json` 后重下 |
| 下载速度归零 | 单连接被限速/假死 | 分块下载器自动超时重试；检查网络源（见 06 章） |
| ghcr 镜像拉不动 | blob CDN 被限速 | 用 ghcr.nju.edu.cn 镜像 + digest 校验 |
| 服务起不来 / 端口占用 | 上次未正常停止 | `./stop-deepseek-v4-flash-dspark.sh` 后重试 |
| 单请求输出数万 token 不停 | `DEFAULT_THINKING=max` + 开放提示词 | 请求加 `thinking:false`；压测改 `low/off` |
| 高并发下内存涨 | vLLM prefix-cache 老版本泄漏 | 使用 Anemll 0.1.1 镜像（已修复） |
| SSH 断连后下载中断 | 进程挂在会话上 | 一律 `nohup setsid` + `@reboot` 自恢复 |

## 9.5 升级与回滚

- 换镜像：改 `.env.dspark` 的 `DSPARK_VLLM_IMAGE` → 双机 `docker pull` → 重启。
- 换模型版本：重下模型缓存 → 更新 `DSPARK_MODEL` 与 `DSPARK_ENCODING_FILE` → 重启。
- 回滚网络：删除集群会清掉双机 SSH 与网络计划（Sync → Settings → Clusters → Delete），
  网络计划文件：`/etc/netplan/99-nvidia-sync-cluster.yaml`。
