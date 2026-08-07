# 01 硬件准备与拓扑

## 1.1 需要的硬件

| 组件 | 数量 | 说明 |
|---|---|---|
| NVIDIA DGX Spark（GB10） | 2 | 128 GB 统一内存，Blackwell sm_121 |
| QSFP112 DAC 直连铜缆（400GbE，仅以太网模式） | 1 | 支持型号：Amphenol `NJAAKK-N911`、Luxshare `LMTQF022-SD-R` |
| 千兆交换机 / 家用路由器 | 1 | 管理网（有线或 Wi-Fi 均可） |
| 装有 NVIDIA Sync 的 Mac / PC | 1 | 用于 Cluster Assistant 配置集群 |

> 官方要求：系统软件 ≥ **2026-04** 版本；线缆必须是官方列出的 QSFP112 DAC，
> 用普通 100G/25G 线会协商不到 200G。

## 1.2 物理口与 Linux 网口映射（重点）

每台 DGX Spark 有 **2 个 QSFP 物理口**，每个物理口在 Linux 下映射为 **2 个网口**
（ConnectX-7 双 PCIe x4 链路，各 ~100G，合计 200G）：

| 物理口 | 链路 0（100G） | 链路 1（100G） |
|---|---|---|
| Port 0 | `enp1s0f0np0` / RoCE `rocep1s0f0` | `enP2p1s0f0np0` / RoCE `roceP2p1s0f0` |
| Port 1 | `enp1s0f1np1` / RoCE `rocep1s0f1` | `enP2p1s0f1np1` / RoCE `roceP2p1s0f1` |

**插一根线，两端各有 2 个口同时亮（Link UP）是正常的**，不要以为是插了两根线。

## 1.3 插线与拓扑

- 两台机器**直连**（不经过交换机），一根线即可：`A 的任一物理口 ↔ B 的任一物理口`。
- **两台可以插不同的物理口**（例如 A 插 Port 0、B 插 Port 1），Cluster Assistant 会自动识别，
  但 07 章的 NCCL 配置必须按各台实际口位填写。
- 不要在同一链路上插两根线（不会提速）。

## 1.4 接线后检查

在两台上分别执行（`<iface>` 换成你的有线口）：

```bash
ip -br link show | grep -E "enp1s0f|enP2p1s0f"
sudo ethtool <iface> | grep -E "Speed|Link detected"
```

预期：**插线的物理口两个链路均为 `Speed: 200000Mb/s` 且 `Link detected: yes`**；
没插线的口为 `no (No cable)`。

同时确认管理网（有线 `enP7s7` 或 Wi-Fi `wlP9s9`）有 IP 且两台互通。

## 官方参考

- [DGX Spark 用户指南（网络部分）](https://docs.nvidia.com/dgx/dgx-spark/)
- [Cluster Assistant（支持的线缆型号）](https://docs.nvidia.com/sync/latest/cluster-assistant.html)
- [连接两台 Spark playbook](https://build.nvidia.com/spark/connect-two-sparks)
