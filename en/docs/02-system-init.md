# 02 System Initialization, OTA Upgrade and Firmware

## 2.1 First Boot

1. Connect power and a display/keyboard, or connect to the network and SSH in (the username is
   created during the first-boot wizard; use the same `<USER>` on both machines).
2. Complete the NVIDIA first-boot wizard (accept the EULA, configure networking).
3. Confirm the system version:

```bash
cat /etc/dgx-release 2>/dev/null; cat /etc/os-release | head -2
```

> DGX Spark uses `/etc/dgx-release` (contains `DGX_OTA_VERSION`, e.g. 7.5.0) for the system/OTA
> version; there is no Jetson-style `/etc/nv_tegra_release`.

## 2.2 System Software OTA Upgrade

The system must be ≥ 2026-04 to use Cluster Assistant. The OTA tool ships with the system:
`nvidia-spark-ota-check` (note: **there is no `nv-ota` command**). Recommended flow:

- **GUI (recommended)**: DGX Dashboard → system update; the Dashboard handles the OTA automatically;
- **CLI (headless environment)**:

```bash
# 1) Check current OTA state (torn-score: 0 = fully applied)
sudo nvidia-spark-ota-check summary
sudo nvidia-spark-ota-check torn-score

# 2) Is an update available? (returns JSON)
sudo nvidia-spark-ota-check is-ota-available

# 3) Apply the update: the official one-shot upgrade script (reboot afterwards)
sudo /usr/sbin/nvidia-spark-run-apt-upgrade-once.sh
```

> **Where this command comes from**: `nvidia-spark-ota-check` is an OTA diagnostics/status
> tool that ships with the system, provided by the `nvidia-spark-ota-check` package
> (`/usr/bin/nvidia-spark-ota-check`; sources under `/opt/nvidia/spark-ota-check/`). It is not a
> third-party tool you install yourself. NVIDIA's official OS and Component Update Guide
> recommends the DGX Dashboard for updates; the manual path is
> `sudo apt update && sudo apt dist-upgrade` plus
> `sudo fwupdmgr refresh && sudo fwupdmgr upgrade`, and that page does not mention
> `nvidia-spark-ota-check`. The tool is mainly referenced on the NVIDIA developer forums for
> checking OTA state (torn-score == 0). If the command is missing on your system, just follow
> the official manual update commands above, or check `apt-cache policy nvidia-spark-ota-check`
> to confirm the package is installed.

> Example output: `summary` returns `"detected_ota": "OTA2607", "torn": 0.0` (all 153 checks pass).
> Per-release contents are listed in the official release notes:
> <https://docs.nvidia.com/dgx/dgx-spark/release-notes.html>

> **Reboot afterwards.** A known symptom: after upgrading, `nvidia-smi` reports failure because
> the driver modules were built for the new kernel; a reboot resolves it.

Verify:

```bash
sudo nvidia-spark-ota-check            # expect torn-score: 0
nvidia-smi                             # expect NVIDIA GB10, driver 580.x
/usr/local/cuda-13.0/bin/nvcc --version   # expect CUDA 13.0 (nvcc not on default PATH)
nproc                                  # 20
free -g | head -2                      # expect ~121 Gi
df -h /home | tail -1                  # need ≥ 400 GB free for the model
```

## 2.3 ConnectX-7 / USBPD Firmware (optional but recommended)

```bash
sudo fwupdmgr refresh
sudo fwupdmgr update -y                # flashes firmware and reboots
# after reboot (no USBPD device on this system; check ConnectX-7 and UEFI instead)
fwupdmgr get-devices | grep -A2 "MT2910"   # ConnectX-7 firmware (e.g. 28.45.4028)
sudo nvidia-spark-ota-check summary        # torn-score: 0
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
- [DGX Spark: OS and Component Update Guide](https://docs.nvidia.com/dgx/dgx-spark/os-and-component-update.html)
- [DGX Spark Release Notes (OTA contents)](https://docs.nvidia.com/dgx/dgx-spark/release-notes.html)
- [Cluster Assistant (system version ≥ 2026-04)](https://docs.nvidia.com/sync/latest/cluster-assistant.html)
