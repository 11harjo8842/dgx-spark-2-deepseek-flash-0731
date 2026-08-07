# 02 System Initialization, OTA Upgrade and Firmware

## 2.1 First Boot

1. Connect power and a display/keyboard, or connect to the network and SSH in (the username is
   created during the first-boot wizard; use the same `<USER>` on both machines).
2. Complete the NVIDIA first-boot wizard (accept the EULA, configure networking).
3. Confirm the system version:

```bash
cat /etc/nv_tegra_release 2>/dev/null; cat /etc/os-release | head -2
```

## 2.2 System Software OTA Upgrade

The system must be ≥ 2026-04 to use Cluster Assistant. Recommended:

- GUI: DGX Dashboard → system update;
- CLI (headless environment):

```bash
sudo nvidia-spark-ota-check
sudo nv-ota 2>/dev/null || sudo apt-get update && sudo apt-get upgrade -y
```

> **Reboot afterwards.** A known symptom: after upgrading, `nvidia-smi` reports failure because
> the driver modules were built for the new kernel; a reboot resolves it.

Verify:

```bash
sudo nvidia-spark-ota-check            # expect torn-score: 0
nvidia-smi                             # expect NVIDIA GB10, driver 580.x
nvcc --version                         # expect CUDA 13.0
nproc                                  # 20
free -g | head -2                      # expect ~121 Gi
df -h /home | tail -1                  # need ≥ 400 GB free for the model
```

## 2.3 ConnectX-7 / USBPD Firmware (optional but recommended)

```bash
sudo fwupdmgr refresh
sudo fwupdmgr update -y                # flashes firmware and reboots
# after reboot
sudo dmidecode -t 11 | grep -i usbpd   # expect latest USBPD firmware (e.g. 5.22)
```

## 2.4 Docker and User Group

```bash
docker --version                       # Docker ships with the system
sudo usermod -aG docker $USER          # run docker without sudo; takes effect on new SSH sessions
```

> Note: `newgrp docker` only affects the current shell; a new SSH session can run `docker ps` directly.

## Official References

- [DGX Spark First Boot](https://docs.nvidia.com/dgx/dgx-spark/first-boot.html)
- [DGX Spark User Guide (software updates)](https://docs.nvidia.com/dgx/dgx-spark/)
- [Cluster Assistant (system version ≥ 2026-04)](https://docs.nvidia.com/sync/latest/cluster-assistant.html)

