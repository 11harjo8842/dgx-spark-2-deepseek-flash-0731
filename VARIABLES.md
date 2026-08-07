# 变量总表（脱敏对照）

复现前，请把下表所有 `<占位符>` 替换成你自己的实际值。**文档正文中不会出现任何真实值。**

| 占位符 | 含义 | 示例/取值说明 |
|---|---|---|
| `<USER>` | 两台机器统一用户名（UID/GID 建议一致，如 1000） | 如 `aiuser` |
| `<HOSTNAME_A>` | head（主）节点主机名 | 如 `spark-a` |
| `<HOSTNAME_B>` | worker（从）节点主机名 | 如 `spark-b` |
| `<IP_MGMT_A>` | head 管理 IP（你 SSH 用的地址） | 同一 LAN 内 |
| `<IP_MGMT_B>` | worker 管理 IP | 同一 LAN 内 |
| `<MGMT_IF>` | 管理网口（NCCL 引导面用，两台一致） | 有线 `enP7s7` 或 Wi-Fi `wlP9s9` |
| `<IP_FABRIC_A>` | head 集群网 IP（Cluster Assistant 生成） | 示例 `10.100.192.1` |
| `<IP_FABRIC_B>` | worker 集群网 IP | 示例 `10.100.192.2` |
| `<IP_FABRIC_A2>` / `<IP_FABRIC_B2>` | 第二条链路 IP（同子网对） | 示例 `10.100.193.1/2` |
| `<NCCL_HCA_A>` | head 的 RoCE 设备（线插哪个物理口就对应哪个） | `rocep1s0f0` 或 `rocep1s0f1` |
| `<NCCL_HCA_B>` | worker 的 RoCE 设备 | 同上，两台可以不同 |
| `<NCCL_IF_A>` | head 的 RoCE 网口 | `enp1s0f0np0` / `enp1s0f1np1` 等 |
| `<NCCL_IF_B>` | worker 的 RoCE 网口 | 同上 |
| `<WIFI_SSID>` / `<WIFI_PASS>` | （可选）管理 Wi-Fi | 无则用有线 |
| `<PROXY_HOST>` / `<PROXY_PORT>` | （可选）代理服务器地址/端口 | 仅中国大陆网络需要 |
| `<PROXY_USER>` / `<PROXY_PASS>` | （可选）代理账号密码 | 仅代理需要认证时 |
| `<HF_MODEL>` | HuggingFace 模型 id | `deepseek-ai/DeepSeek-V4-Flash-0731` |
| `<HF_MODEL_SHORT>` | 模型 id 的组织名去掉后的短名（用于本地路径） | `DeepSeek-V4-Flash-0731` |
| `<IMAGE>` | vLLM 运行时镜像 | `ghcr.io/anemll/dspark-vllm-gx10:0.1.1` |

## 常见网络事实（中国大陆环境实测）

| 目标 | 直连 | 经代理 | 结论 |
|---|---|---|---|
| huggingface.co | 不通 | 极慢（~0 MB/s） | 用 `hf-mirror.com` 直连 |
| hf-mirror.com | ~27 MB/s | — | 分块并发可到 30–40 MB/s |
| Xet 协议（cas-bridge） | 403 | 403 | 必须 `HF_HUB_DISABLE_XET=1` |
| ghcr.io（API） | 快 | 慢/不稳 | API 可直连 |
| ghcr.io（blob 下载） | 被限速 ~17 KB/s | 不稳 | 用镜像 `ghcr.nju.edu.cn`（~24 MB/s，digest 一致） |

> 海外网络可直接使用官方源，06 章给出了替代命令。
