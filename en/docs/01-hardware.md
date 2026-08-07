# 01 Hardware Preparation and Topology

## 1.1 Required Hardware

| Component | Qty | Notes |
|---|---|---|
| NVIDIA DGX Spark (GB10) | 2 | 128 GB unified memory, Blackwell sm_121 |
| QSFP112 DAC direct-attach cable (400GbE, Ethernet-mode only) | 1 | Supported: Amphenol `NJAAKK-N911`, Luxshare `LMTQF022-SD-R` |
| Gigabit switch / home router | 1 | management LAN (wired or Wi-Fi) |
| Mac / PC with NVIDIA Sync | 1 | used by Cluster Assistant |

> Official requirements: system software ≥ **2026-04**; the cable must be an officially supported
> QSFP112 DAC — an ordinary 100G/25G cable will not negotiate 200G.

## 1.2 Physical Ports vs Linux Interfaces (important)

Each DGX Spark has **2 QSFP physical ports**; each physical port maps to **2 Linux interfaces**
(dual PCIe x4 links on the ConnectX-7, ~100G each, 200G combined):

| Physical port | Link 0 (100G) | Link 1 (100G) |
|---|---|---|
| Port 0 | `enp1s0f0np0` / RoCE `rocep1s0f0` | `enP2p1s0f0np0` / RoCE `roceP2p1s0f0` |
| Port 1 | `enp1s0f1np1` / RoCE `rocep1s0f1` | `enP2p1s0f1np1` / RoCE `roceP2p1s0f1` |

**With one cable plugged in, both interfaces of the cabled port will show Link UP — this is normal.**

## 1.3 Cabling and Topology

- The two machines are connected **directly** (no switch) with a single cable: `any physical port on A ↔ any physical port on B`.
- **The two machines may use different physical ports** (e.g. A on Port 0, B on Port 1); Cluster
  Assistant detects this automatically, but the NCCL configuration in chapter 07 must match the
  actual port on each machine.
- Do not plug two cables into the same link (it will not improve speed).

## 1.4 Post-Cabling Checks

Run on both machines (replace `<iface>` with your wired interface):

```bash
ip -br link show | grep -E "enp1s0f|enP2p1s0f"
sudo ethtool <iface> | grep -E "Speed|Link detected"
```

Expected: both links of the cabled port show `Speed: 200000Mb/s` and `Link detected: yes`;
the uncabled port shows `no (No cable)`.

Also confirm the management network (wired `enP7s7` or Wi-Fi `wlP9s9`) has an IP and both machines can reach each other.

## Official References

- [DGX Spark User Guide (networking)](https://docs.nvidia.com/dgx/dgx-spark/)
- [Cluster Assistant (supported cables)](https://docs.nvidia.com/sync/latest/cluster-assistant.html)
- [Connect Two Sparks playbook](https://build.nvidia.com/spark/connect-two-sparks)

