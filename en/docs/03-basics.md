# 03 Base Configuration: Users, SSH, Network and Proxy

## 3.1 Uniform User and Passwordless sudo

Create/use the same username `<USER>` on both machines (keep UID/GID identical, e.g. 1000) and
configure passwordless sudo (required by Cluster Assistant and the deployment scripts):

```bash
# on each machine
sudo tee /etc/sudoers.d/<USER>-nopasswd <<< "<USER> ALL=(ALL) NOPASSWD:ALL"
sudo chmod 440 /etc/sudoers.d/<USER>-nopasswd
```

> **Security note**: set a strong sudo password; this document contains no credential examples.

## 3.2 Two-Way Passwordless SSH + Hostname Resolution

On A (head) generate a key and distribute the public key to B and to itself:

```bash
# on A
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
ssh-copy-id <USER>@<IP_MGMT_B>
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys   # SSH to self (mpirun needs this)
```

On B, do the "trust yourself" step as well:

```bash
# on B
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
```

`/etc/hosts` (both machines) and `~/.ssh/config` (alias on A):

```text
<IP_MGMT_A>  <HOSTNAME_A>  spark-a
<IP_MGMT_B>  <HOSTNAME_B>  spark-b
```

```text
Host spark-b
  HostName <IP_MGMT_B>
  User <USER>
```

Verify: `ssh spark-b hostname` connects without a password.

## 3.3 Management Network

- Use the same management interface on both machines (wired `enP7s7` or Wi-Fi `wlP9s9`);
  NCCL bootstrap uses that interface name.
- Record each machine's management IP (`<IP_MGMT_A>/<IP_MGMT_B>`) — needed by the NCCL test and
  the start script.

```bash
ip -4 addr show enP7s7        # or wlP9s9
```

## 3.4 (Optional, China mainland) Proxy Configuration

If downloads are restricted, run a proxy client on each machine (e.g. naive) and configure the
system. **Replace all real credentials with `<PROXY_*>` placeholders.**

Proxy client config (masked example; use your actual ports):

```json
{
  "listen": "socks://0.0.0.0:1080,http://127.0.0.1:1087",
  "proxy": "https://<PROXY_USER>:<PROXY_PASS>@<PROXY_HOST>:<PROXY_PORT>"
}
```

System-level proxy (`/etc/environment`, apt, docker):

```bash
cat >> /etc/environment <<'EOF'
http_proxy=http://127.0.0.1:1087
https_proxy=http://127.0.0.1:1087
all_proxy=socks5h://127.0.0.1:1080
no_proxy=localhost,127.0.0.1,<LAN_SUBNET>,169.254.0.0/16,.local
EOF
```

> **Hard-won lesson**: for large downloads from huggingface.co / ghcr.io the proxy measured
> ~0 MB/s or endless retries. Chapter 06 provides direct-mirror alternatives. The model downloader
> explicitly clears proxy environment variables.

## Official References

- [NVIDIA Sync installation (Adding a Device)](https://docs.nvidia.com/sync/latest/getting-started.html)
- [Cluster Assistant prerequisites (users/SSH/sudo)](https://docs.nvidia.com/sync/latest/cluster-assistant.html)

