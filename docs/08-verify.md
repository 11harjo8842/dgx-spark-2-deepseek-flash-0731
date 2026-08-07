# 08 验证与性能

## 8.1 API 健康检查

```bash
curl http://<IP_MGMT_A>:8888/health          # 期望 200
curl http://<IP_MGMT_A>:8888/v1/models       # 期望 max_model_len: 1048576
```

## 8.2 最小对话

```bash
curl http://<IP_MGMT_A>:8888/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"deepseek-v4-flash-0731",
       "messages":[{"role":"user","content":"计算 17*23 等于多少，只回答数字"}],
       "temperature":0,"max_tokens":200,
       "chat_template_kwargs":{"thinking":false}}'
```

期望：`391`，秒级返回。若需模型思考（reasoning），去掉 `thinking:false` 或保持默认 `max`。

## 8.3 仓库自带脚本（Annotation 1：冒烟测试）

仓库提供 `smoke-deepseek-v4-flash-dspark.sh`（并发冒烟）、`status-...`、`logs-...`、`stop-...`：

```bash
cd ~/DeepSeek-v4-Flash-DSpark-2x-DGX-Spark
./smoke-deepseek-v4-flash-dspark.sh          # 默认 6 并发；CONCURRENCY=12 ./smoke-... 可调
./status-deepseek-v4-flash-dspark.sh
./logs-deepseek-v4-flash-dspark.sh
```

实测结果：**6/6 请求全部成功**。

## 8.4 基准压测（注意思考级别）

```bash
cd ~/DeepSeek-v4-Flash-DSpark-2x-DGX-Spark
python3 scripts/benchmark-0731.py \
  --base-url http://127.0.0.1:8888/v1 \
  --model deepseek-v4-flash-0731 \
  --prompt-lengths 256,2048,8192 --concurrency 1,3,6 \
  --output results/benchmark-smoke.json
```

> **重要坑**：`DEFAULT_THINKING=max` 时模型会产生超长推理链（单个请求可生成数万 token），
> 一个用例要 10–20+ 分钟甚至跑飞。**压测前请把 `.env.dspark` 的 `DEFAULT_THINKING` 改为
> `low` 或 `off` 并重启服务**，否则结果不可用。

## 8.5 性能预期

本方案实测（DSpark MTP5、NVFP4 DS-MLA、TP=2）：

| 指标 | 实测/预期 |
|---|---|
| 单流 decode（含推理） | ~60–80 tok/s（热机 78–80） |
| prefill | 372 token 提示 ~99 tok/s；短提示可达 ~2000 tok/s |
| DSpark 投机接受率 | ~91%（平均接受长度 5.5+） |
| GPU 利用率 | ~95% |
| KV 池 | 双机 ~183 万 token（1M 上下文下并发 ~1.75×） |
| 高并发聚合（社区，thinking=off） | 最高约 340 tok/s @ c32 |

KV 池是共享的：总在线 token ≤ ~1.83M，长上下文与高并发互斥（详见 [09 章](09-ops.md)）。

