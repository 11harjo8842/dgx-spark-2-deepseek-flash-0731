# 04 Two-Node Cluster: NVIDIA Sync + Cluster Assistant

## 4.1 Install NVIDIA Sync

- Download `nvidia-sync.dmg` from [build.nvidia.com/spark/connect-to-your-spark](https://build.nvidia.com/spark/connect-to-your-spark) (macOS), drag into Applications.
- Open the app and add both devices (by IP or device name, per the Sync wizard).

## 4.2 Create the Cluster

Sync → **Settings → Cluster Assistant → Add New Cluster**:

1. Name the cluster (e.g. `spark-cluster`).
2. Select both devices.
3. **Device Checks**: SSH reachable, GB10 detected, OS version, sudo access (no password prompt if
   passwordless sudo is configured).
4. **User Check**: passes if username/UID/GID match (warns otherwise; you may continue).
5. (optional) Rename devices.
6. **Network Check**: QSFP cable detected → negotiates 200 Gbit/s → confirm the network changes.
7. **Link Speed Test**: per-link, lower bound **184 Gbit/s**.
8. **Inter-device SSH**: auto-configures node-to-node SSH (may take a few minutes).
9. **Success**: **Copy** the network info and save it locally.

## 4.3 Configuration Artifacts

Cluster Assistant writes `/etc/netplan/99-nvidia-sync-cluster.yaml` on both machines, assigning
an IP per 100G link (example):

| Node | Link 0 | Link 1 |
|---|---|---|
| head | `10.100.192.1/24` | `10.100.193.1/24` |
| worker | `10.100.192.2/24` | `10.100.193.2/24` |

These are the **fabric IPs** (`<IP_FABRIC_A/B>`, `<IP_FABRIC_A2/B2>`) used by NCCL/vLLM later.

## 4.4 Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Speed test shows only 25G | network plan just written but not active: **reboot both (cable plugged in) then Run Test Again**; if still low, check the cable model |
| Device check fails | system not upgraded to 2026-04+; sudo needs password or NOPASSWD |
| SSH check fails | Sync machine must be on the same LAN and able to SSH to the devices |
| 200G reported but slow test | confirm a single supported QSFP112 DAC; reboot and retest |

> In this setup, 25G was caused by the config not yet being applied; after a reboot the test passed,
> and iperf3 measured ~107 Gbit/s per link (≈214 Gbit/s combined).

## Official References

- [Cluster Assistant documentation](https://docs.nvidia.com/sync/latest/cluster-assistant.html)
- [NVIDIA Sync download page](https://build.nvidia.com/spark/connect-to-your-spark)
- [NVIDIA Sync Getting Started](https://docs.nvidia.com/sync/latest/getting-started.html)
- [DGX Spark ConnectX-7 networking (User Guide)](https://docs.nvidia.com/dgx/dgx-spark/)

