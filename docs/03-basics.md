# 03 基础配置：用户、SSH、网络与代理

## 3.1 统一用户与 sudo 免密

两台机器创建/使用统一用户名 `<USER>`（UID/GID 建议一致，如 1000），并配置 sudo 免密
（Cluster Assistant 与部署脚本需要）：

```bash
# 在每台机器上执行
sudo tee /etc/sudoers.d/<USER>-nopasswd <<< "<USER> ALL=(ALL) NOPASSWD:ALL"
sudo chmod 440 /etc/sudoers.d/<USER>-nopasswd
```

> **安全提示**：请设置强 sudo 密码；文档不包含任何口令示例。

## 3.2 双向 SSH 免密 + 主机名解析

以 A（head）为主，在 A 上生成密钥并把公钥分发到 B 和自身：

```bash
# A 上
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
ssh-copy-id <USER>@<IP_MGMT_B>
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys   # 自己 SSH 自己（mpirun 需要）
```

在 B 上做同样的“自己信任自己”：

```bash
# B 上
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
```

`/etc/hosts`（两台都加）与 `~/.ssh/config`（A 上加别名）：

```text
<IP_MGMT_A>  <HOSTNAME_A>  spark-a
<IP_MGMT_B>  <HOSTNAME_B>  spark-b
```

```text
Host spark-b
  HostName <IP_MGMT_B>
  User <USER>
```

验证：`ssh spark-b hostname` 免密直达。

## 3.3 管理网络

- 管理网口建议两台一致（有线 `enP7s7` 或 Wi-Fi `wlP9s9`），NCCL 引导面要用同一个网口名。
- 记录每台的管理 IP（`<IP_MGMT_A>/<IP_MGMT_B>`）——后续 NCCL 测试与启动脚本都要用。

```bash
ip -4 addr show enP7s7        # 或 wlP9s9
```

## 3.4 （可选，中国大陆网络）代理配置

如果需要在受限网络中下载，可在每台机器放一个代理客户端（如 naive），并做系统级配置。
**所有真实口令用 `<PROXY_*>` 占位符替换。**

代理客户端（脱敏示例，端口以实际为准）：

```json
{
  "listen": "socks://0.0.0.0:1080,http://127.0.0.1:1087",
  "proxy": "https://<PROXY_USER>:<PROXY_PASS>@<PROXY_HOST>:<PROXY_PORT>"
}
```

系统级代理（`/etc/environment`、apt、docker）：

```bash
cat >> /etc/environment <<'EOF'
http_proxy=http://127.0.0.1:1087
https_proxy=http://127.0.0.1:1087
all_proxy=socks5h://127.0.0.1:1080
no_proxy=localhost,127.0.0.1,<LAN_SUBNET>,169.254.0.0/16,.local
EOF
```

> **重要经验**：代理对 huggingface.co / ghcr.io 的大流量实测几乎不可用（0 MB/s 或无限重试），
> 06 章给出了直连镜像方案。模型下载脚本会显式清空代理环境变量。

## 官方参考

- [NVIDIA Sync 安装（Adding a Device）](https://docs.nvidia.com/sync/latest/getting-started.html)
- [Cluster Assistant 前置要求（用户/SSH/sudo）](https://docs.nvidia.com/sync/latest/cluster-assistant.html)
