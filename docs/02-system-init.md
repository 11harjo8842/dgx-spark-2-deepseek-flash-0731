# 02 系统初始化、OTA 升级与固件

## 2.1 首次启动

1. 接电源、显示器/键盘，或接好网络后用 SSH 登录（用户名在首启向导中创建，建议两台统一 `<USER>`）。
2. 完成 NVIDIA 首启向导（同意 EULA、配置网络）。
3. 确认系统版本满足要求：

```bash
cat /etc/nv_tegra_release 2>/dev/null; cat /etc/os-release | head -2
```

## 2.2 系统软件 OTA 升级

系统版本必须 ≥ 2026-04 才能使用 Cluster Assistant。推荐方式：

- 图形界面：DGX Dashboard → 系统更新；
- 命令行（无显示器环境）：

```bash
# 检查并应用全部更新（官方工具随系统安装）
sudo nvidia-spark-ota-check
sudo nv-ota 2>/dev/null || sudo apt-get update && sudo apt-get upgrade -y
```

> **务必重启**，并在重启后再次确认没有待升级项。曾经遇到过：驱动模块编译期与当前内核
> 不一致导致 `nvidia-smi` 报 failed，重启后即恢复。

验证：

```bash
sudo nvidia-spark-ota-check            # 期望 torn-score: 0
nvidia-smi                             # 期望 NVIDIA GB10, 驱动 580.x
nvcc --version                         # 期望 CUDA 13.0
nproc                                  # 20
free -g | head -2                      # 期望 ~121 Gi
df -h /home | tail -1                  # 模型需要 ≥ 400 GB 空闲
```

## 2.3 ConnectX-7 / USBPD 固件（可选但推荐）

```bash
sudo fwupdmgr refresh
sudo fwupdmgr update -y                # 会刷固件并重启
# 重启后验证
sudo dmidecode -t 11 | grep -i usbpd   # 期望 USBPD 固件为最新（如 5.22）
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
- [Cluster Assistant（系统版本要求 ≥ 2026-04）](https://docs.nvidia.com/sync/latest/cluster-assistant.html)
