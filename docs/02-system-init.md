# 02 系统初始化、OTA 升级与固件

## 2.1 首次启动

1. 接电源、显示器/键盘，或接好网络后用 SSH 登录（用户名在首启向导中创建，建议两台统一 `<USER>`）。
2. 完成 NVIDIA 首启向导（同意 EULA、配置网络）。
3. 确认系统版本满足要求：

```bash
cat /etc/dgx-release 2>/dev/null; cat /etc/os-release | head -2
```

> DGX Spark 用 `/etc/dgx-release`（含 `DGX_OTA_VERSION`，如 7.5.0）确认系统/OTA 版本；
> 没有 Jetson 的 `/etc/nv_tegra_release`。

## 2.2 系统软件 OTA 升级

系统版本必须 ≥ 2026-04 才能使用 Cluster Assistant。OTA 工具是系统自带的
`nvidia-spark-ota-check`（注意：**不存在** `nv-ota` 这个命令），推荐流程：

- **图形界面（推荐）**：DGX Dashboard → 系统更新，由 Dashboard 自动处理 OTA；
- **命令行（无显示器环境）**：

```bash
# 1) 检查当前 OTA 状态（torn-score: 0 = 已完整应用）
sudo nvidia-spark-ota-check summary
sudo nvidia-spark-ota-check torn-score

# 2) 是否有可用更新（返回 JSON）
sudo nvidia-spark-ota-check is-ota-available

# 3) 应用更新：官方一次性升级脚本（应用后需重启）
sudo /usr/sbin/nvidia-spark-run-apt-upgrade-once.sh
```

> **命令来源**：`nvidia-spark-ota-check` 是系统出厂自带的 OTA 诊断/状态工具，由
> `nvidia-spark-ota-check` 软件包提供（本机路径 `/usr/bin/nvidia-spark-ota-check`，
> 代码在 `/opt/nvidia/spark-ota-check/`），并非用户安装的第三方命令。
> NVIDIA 官方文档（OS and Component Update Guide）主推 DGX Dashboard 更新；
> 手动更新方式是 `sudo apt update && sudo apt dist-upgrade` +
> `sudo fwupdmgr refresh && sudo fwupdmgr upgrade`，该页面并未列出
> `nvidia-spark-ota-check`。此工具主要见于 NVIDIA 开发者论坛，用于查看 OTA 状态
> （torn-score 是否为 0）。若系统里没有该命令，直接用上述官方手动方式更新即可，
> 或先 `apt-cache policy nvidia-spark-ota-check` 确认包是否已安装。

> 示例输出：`summary` 返回 `"detected_ota": "OTA2607", "torn": 0.0`（153 项检查全部通过）。
> 各版本更新内容与发布说明见官方 release notes：
> <https://docs.nvidia.com/dgx/dgx-spark/release-notes.html>

> **务必重启**，并在重启后再次确认没有待升级项。曾经遇到过：驱动模块编译期与当前内核
> 不一致导致 `nvidia-smi` 报 failed，重启后即恢复。

验证：

```bash
sudo nvidia-spark-ota-check            # 期望 torn-score: 0
nvidia-smi                             # 期望 NVIDIA GB10, 驱动 580.x
/usr/local/cuda-13.0/bin/nvcc --version   # 期望 CUDA 13.0（nvcc 默认不在 PATH）
nproc                                  # 20
free -g | head -2                      # 期望 ~121 Gi
df -h /home | tail -1                  # 模型需要 ≥ 400 GB 空闲
```

## 2.3 ConnectX-7 / USBPD 固件（可选但推荐）

```bash
sudo fwupdmgr refresh
sudo fwupdmgr update -y                # 会刷固件并重启
# 重启后验证（本系统无 USBPD 设备；重点看 ConnectX-7 与 UEFI 固件）
fwupdmgr get-devices | grep -A2 "MT2910"   # ConnectX-7 固件（如 28.45.4028）
sudo nvidia-spark-ota-check summary        # torn-score: 0
```

## 2.4 Docker 与用户组

```bash
docker --version                       # 系统自带 Docker
sudo usermod -aG docker $USER          # 免 sudo 用 docker；新 SSH 会话生效
```

> 说明：`newgrp docker` 只对当前 shell 生效；新建 SSH 会话即可直接 `docker ps`。

## 官方参考

- [DGX Spark 首次启动](https://docs.nvidia.com/dgx/dgx-spark/first-boot.html)
- [DGX Spark 用户指南（软件更新）](https://docs.nvidia.com/dgx/dgx-spark/)
- [DGX Spark：OS and Component Update Guide](https://docs.nvidia.com/dgx/dgx-spark/os-and-component-update.html)
- [DGX Spark Release Notes（OTA 内容）](https://docs.nvidia.com/dgx/dgx-spark/release-notes.html)
- [Cluster Assistant（系统版本要求 ≥ 2026-04）](https://docs.nvidia.com/sync/latest/cluster-assistant.html)
