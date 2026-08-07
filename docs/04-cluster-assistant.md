# 04 双机集群：NVIDIA Sync + Cluster Assistant

## 4.1 安装 NVIDIA Sync

NVIDIA Sync 官方支持 **Windows / macOS / Ubuntu** 三种平台，任选其一即可（不需要 Mac）：

- **Windows**：在 [build.nvidia.com/spark/connect-to-your-spark](https://build.nvidia.com/spark/connect-to-your-spark)
  下载 Windows 安装器（`.exe`），双击安装。
- **macOS**：下载 `nvidia-sync.dmg`，拖入 Applications。
- **Ubuntu**：配置官方 apt 源后安装：
  ```bash
  curl -fsSL https://workbench.download.nvidia.com/stable/linux/gpgkey | sudo tee -a /etc/apt/trusted.gpg.d/ai-workbench-desktop-key.asc
  echo "deb https://workbench.download.nvidia.com/stable/linux/debian default proprietary" | sudo tee -a /etc/apt/sources.list
  sudo apt update && sudo apt install -y nvidia-sync
  ```

- 打开后添加两台设备（可用 IP 或设备名，见 Sync 向导）。

## 4.2 创建集群

Sync → **Settings → Cluster Assistant → Add New Cluster**：

1. 命名集群（如 `spark-cluster`）。
2. 选择两台设备。
3. **Device Checks**：SSH 可达、GB10 识别、系统版本、sudo 权限（已配免密则不弹密码）。
4. **User Check**：两台用户名/UID/GID 一致则通过（不一致会提示，可继续）。
5. （可选）重命名设备。
6. **Network Check**：检测到 QSFP 线 → 协商 200 Gbit/s → 确认网络配置变更。
7. **Link Speed Test**：逐链路测速，要求下限 **184 Gbit/s**。
8. **Inter-device SSH**：自动配置双机互访（可能耗时数分钟）。
9. **Success**：把网络信息 **Copy** 保存到本地文件备用。

## 4.3 配置产物

Cluster Assistant 会在两台写入 `/etc/netplan/99-nvidia-sync-cluster.yaml`，给每个 100G 链路
分配 IP（示例）：

| 节点 | 链路 0 | 链路 1 |
|---|---|---|
| head | `10.100.192.1/24` | `10.100.193.1/24` |
| worker | `10.100.192.2/24` | `10.100.193.2/24` |

这些就是后续 NCCL/vLLM 使用的 **fabric IP**（`<IP_FABRIC_A/B>`、`<IP_FABRIC_A2/B2>`）。

## 4.4 常见问题

| 现象 | 原因/处理 |
|---|---|
| 测速只有 25G | 网络计划刚写入尚未生效：**重启两台（线插着）后 Run Test Again**；若仍低，检查线缆型号 |
| 设备检查失败 | 系统未升级到 2026-04+；sudo 需免密或输入密码 |
| SSH 检查失败 | Sync 所在机器需与设备同网段且可 SSH |
| 端口显示 200G 但测速低 | 确认只有一根官方型号 QSFP112 DAC；重启后再测 |

> 本方案实测：测速 25G 是配置尚未生效导致，重启后稳定通过，且随后 iperf3 实测两条链路
> 各 ~107 Gbit/s（合计 ~214 Gbit/s）。

## 官方参考

- [Cluster Assistant 官方文档](https://docs.nvidia.com/sync/latest/cluster-assistant.html)
- [NVIDIA Sync 下载页](https://build.nvidia.com/spark/connect-to-your-spark)
- [NVIDIA Sync Getting Started](https://docs.nvidia.com/sync/latest/getting-started.html)
- [DGX Spark ConnectX-7 网络说明（用户指南）](https://docs.nvidia.com/dgx/dgx-spark/)
