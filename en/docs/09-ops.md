# 09 Operations, Auto-Resume and Troubleshooting

## 9.1 Daily Commands

```bash
cd ~/DeepSeek-v4-Flash-DSpark-2x-DGX-Spark
./status-deepseek-v4-flash-dspark.sh   # container state on both nodes
./logs-deepseek-v4-flash-dspark.sh     # logs on both nodes
./smoke-deepseek-v4-flash-dspark.sh    # smoke test
./stop-deepseek-v4-flash-dspark.sh     # stop (handled by the script)
docker compose --env-file .env.dspark -f docker-compose.dspark.yml ps
```

## 9.2 Boot-Time Auto-Resume (download tasks)

```bash
chmod +x ~/resume-downloads.sh
( crontab -l 2>/dev/null | grep -v resume-downloads.sh; \
  echo "@reboot $HOME/resume-downloads.sh" ) | crontab -
```

After a reboot it automatically resumes incomplete model downloads and re-pulls a missing image.
All long tasks should run with `nohup setsid ... < /dev/null &` so they detach from SSH
(PPID=1 and TTY=? confirm success).

## 9.2b Inference Service Auto-Start (systemd, recommended)

Starting the service only via `./start-deepseek-v4-flash-dspark.sh` means it will **not come back
after a machine reboot**. This setup installs one systemd unit per node for boot auto-start plus
crash self-healing (masked templates are in this package's `scripts/`):

| Node | Unit | Behavior |
|---|---|---|
| head | `dspark-vllm.service` | On boot runs the start wrapper: API healthy → skip; worker up but head missing → `docker compose up` the head and wait; neither up → run `./start-...`. `Restart=on-failure` (60s interval, max 5 in 600s) |
| worker | `dspark-vllm-worker.service` | On boot ensures the worker container is running (idempotent) |
| both | container `deepseek-v4-flash-vllm-dspark-1` | `restart: unless-stopped` (already in the compose file, see chapter 07) |

Install (run `scripts/install-autostart.sh` on the head; first replace the
`<USER>`, `<IP_MGMT_B>`, `<REPO_PATH>` placeholders in the scripts):

```bash
bash install-autostart.sh
# verify (both must print enabled)
systemctl is-enabled dspark-vllm.service        # head
systemctl is-enabled dspark-vllm-worker.service # worker
```

Daily start/stop/restart (equivalent to the manual scripts; the head unit also
orchestrates the worker):

```bash
sudo systemctl start dspark-vllm.service     # idempotent; waits for the API on cold start (up to ~20 min)
sudo systemctl stop dspark-vllm.service      # stops containers on both nodes
sudo systemctl restart dspark-vllm.service
sudo systemctl status dspark-vllm.service
sudo journalctl -u dspark-vllm.service -f
```

> `systemctl stop` runs the ExecStop wrapper (stops head + worker together); to fully
> disable auto-start: `sudo systemctl disable dspark-vllm.service` (same on the worker).

## 9.3 Kernel and Memory Hardening

```bash
echo vm.compaction_proactiveness=0 | sudo tee /etc/sysctl.d/99-dsv4.conf
sudo sysctl -w vm.compaction_proactiveness=0
```

The community has observed whole-machine reboots under load: `kcompactd` soft-lockup combined with
an NVIDIA `mstflint` polling NULL-deref; `vm.compaction_proactiveness=0` is defense-in-depth.
Also note the `mlx5_core insufficient power 27W` log is a normal trait of the integrated CX-7 on
GB10 — not a fault.

## 9.4 Troubleshooting Table

| Symptom | Cause | Fix |
|---|---|---|
| Cluster speed test 25G | network plan not active | reboot both nodes (cable stays plugged in), then Run Test Again — the reboot is what activates the config; replugging the cable alone does not help |
| `nvidia-smi` fails | reboot pending after upgrade | reboot |
| NCCL `ibv_modify_qp` / GID error | RoCEv2 GID index drift | keep `NCCL_IB_GID_AUTO=1`; or inspect the GID table per chapter 05 |
| mpirun hangs | SSH/host-key issue | validate with a minimal `mpirun hostname` first |
| Model download hash-fail | old downloader bug / dirty sidecar | use the bundled script (fixed); delete `*.chunks.json` and re-download |
| Download speed drops to zero | single connection throttled/stalled | the chunked downloader auto-retries; check sources per chapter 06 |
| ghcr pull stuck | blob CDN throttled | use ghcr.nju.edu.cn mirror + digest verification |
| Service won't start / port busy | previous instance not stopped | `./stop-deepseek-v4-flash-dspark.sh` then retry |
| One request generates endless tokens | `DEFAULT_THINKING=max` + open-ended prompt | add `thinking:false` to the request; set `low/off` for benchmarks |
| Memory grows under load | old vLLM prefix-cache leak | use the Anemll 0.1.1 image (fixed) |
| Downloads die after SSH drop | process attached to session | always `nohup setsid` + `@reboot` auto-resume |

## 9.5 Upgrades and Rollback

- Change image: edit `DSPARK_VLLM_IMAGE` in `.env.dspark` → `docker pull` on both → restart.
- Change model version: re-download the model cache → update `DSPARK_MODEL` and
  `DSPARK_ENCODING_FILE` → restart.
- Roll back networking: deleting the cluster clears node-to-node SSH and the network plan
  (Sync → Settings → Clusters → Delete); netplan file:
  `/etc/netplan/99-nvidia-sync-cluster.yaml`.
