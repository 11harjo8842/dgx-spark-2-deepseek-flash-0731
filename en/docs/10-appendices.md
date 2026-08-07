# 10 Appendices: References and File Inventory

## 10.1 Official Documentation and Repositories (all paths)

| Topic | Path |
|---|---|
| NVIDIA Sync installation | <https://docs.nvidia.com/sync/latest/getting-started.html> |
| Cluster Assistant | <https://docs.nvidia.com/sync/latest/cluster-assistant.html> |
| Sync download page | <https://build.nvidia.com/spark/connect-to-your-spark> |
| DGX Spark User Guide | <https://docs.nvidia.com/dgx/dgx-spark/> |
| DGX Spark First Boot | <https://docs.nvidia.com/dgx/dgx-spark/first-boot.html> |
| Connect Two Sparks playbook | <https://build.nvidia.com/spark/connect-two-sparks> |
| NCCL playbook | <https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/nccl/README.md> |
| vLLM playbook | <https://github.com/NVIDIA/dgx-spark-playbooks/blob/main/nvidia/vllm/README.md> |
| Model card | <https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash-0731> |
| HF API: model info | <https://huggingface.co/api/models/deepseek-ai/DeepSeek-V4-Flash-0731> |
| HF API: file tree (sha256) | <https://huggingface.co/api/models/deepseek-ai/DeepSeek-V4-Flash-0731/tree/main?recursive=true&expand=true> |
| Anemll image source | <https://github.com/Anemll/dspark-vllm-gx10> |
| MiaAI deployment repo | <https://github.com/MiaAI-Lab/DeepSeek-v4-Flash-DSpark-2x-DGX-Spark> |
| MiaAI earlier recipe | <https://github.com/MiaAI-Lab/DeepSeek-V4-Flash-Dual-DGX-Spark-1M-Context> |
| Community setup notes (elsung) | <https://github.com/elsung/dgx-spark-deepseek-v4-flash> (`SETUP-NOTES.md`) |
| Alternative image (aidendle94) | <https://hub.docker.com/r/aidendle94/sparkrun-vllm-ds4-gb10> |
| vLLM source (run_cluster.sh alternative) | <https://github.com/vllm-project/vllm> |
| naiveproxy releases (optional) | <https://github.com/klzgrad/naiveproxy/releases> |
| NGC vLLM catalog (alternative image) | <https://catalog.ngc.nvidia.com/orgs/nvidia/containers/vllm> |
| NCCL source | <https://github.com/NVIDIA/nccl> |
| nccl-tests source | <https://github.com/NVIDIA/nccl-tests> |

## 10.2 Source-Material Index (complete)

The table below covers every source material referenced by this documentation and whether it is
**bundled** with this package or **referenced**. This package only bundles our own scripts and docs
(≈84 KB); all upstream repos/websites/images/models are referenced with official paths, pinned
versions and fetch commands — upstream code is not copied into the package (size and licensing).

| Material | Type | Source (site/repo) | Purpose | Chapters | Form |
|---|---|---|---|---|---|
| NVIDIA Sync (Windows / macOS / Ubuntu desktop app) | desktop app | build.nvidia.com/spark/connect-to-your-spark | cluster config | 04 | reference |
| NVIDIA Sync docs | website | docs.nvidia.com/sync/latest/ | install / Cluster Assistant | 03, 04 | reference |
| DGX Spark User Guide | website | docs.nvidia.com/dgx/dgx-spark/ | first boot / OTA / networking | 01, 02, 04 | reference |
| NVIDIA/dgx-spark-playbooks | GitHub repo | github.com/NVIDIA/dgx-spark-playbooks | official NCCL/vLLM playbooks | 05, 07 | reference |
| NVIDIA/nccl (tag v2.30.7-1) | GitHub repo | github.com/NVIDIA/nccl | NCCL build | 05 | reference |
| NVIDIA/nccl-tests (pin 717b6831) | GitHub repo | github.com/NVIDIA/nccl-tests | two-node test | 05 | reference |
| Anemll/dspark-vllm-gx10 (image 0.1.1) | GitHub repo + container image | github.com/Anemll/dspark-vllm-gx10; ghcr.io (mirror ghcr.nju.edu.cn) | vLLM runtime | 07 | reference (digest-verified) |
| MiaAI DSpark-2x repo (pin a4ce87a2) | GitHub repo | github.com/MiaAI-Lab/DeepSeek-v4-Flash-DSpark-2x-DGX-Spark | compose/start scripts | 07, 08, 09 | reference |
| MiaAI earlier recipe (Dual-DGX-Spark-1M-Context) | GitHub repo | github.com/MiaAI-Lab/DeepSeek-V4-Flash-Dual-DGX-Spark-1M-Context | earlier approach (superseded) | 10 | reference |
| elsung/dgx-spark-deepseek-v4-flash | GitHub repo | github.com/elsung/dgx-spark-deepseek-v4-flash | community pitfalls (GID/Xet/kernel/performance) | 06, 09 | reference |
| aidendle94/sparkrun-vllm-ds4-gb10 | Docker Hub image | hub.docker.com/r/aidendle94/sparkrun-vllm-ds4-gb10 | alternative image family | 07 | reference |
| vllm-project/vllm (run_cluster.sh) | GitHub repo | github.com/vllm-project/vllm (pin 51c1ee9b) | Ray alternative launch | 07 | reference |
| deepseek-ai/DeepSeek-V4-Flash-0731 | HuggingFace model | huggingface.co/deepseek-ai/DeepSeek-V4-Flash-0731 | model weights (166.9 GB) | 06 | reference |
| HF API (sha256 manifest) | web API | huggingface.co/api/models/... | official per-file verification | 06 | reference |
| hf-mirror.com / ghcr.nju.edu.cn | mirror sites | hf-mirror.com; ghcr.nju.edu.cn | restricted-network acceleration | 06, 07 | reference |
| klzgrad/naiveproxy | GitHub releases | github.com/klzgrad/naiveproxy/releases | optional proxy client | 03 | reference |
| NGC vLLM catalog | website | catalog.ngc.nvidia.com/orgs/nvidia/containers/vllm | alternative official image | 07 | reference |
| Our scripts (downloader/auto-resume/preflight/template) | this package | — | core reproduction tooling | 06, 07 | **bundled** |
| This documentation (README/chapters/variables) | this package | — | reproduction guide | all | **bundled** |

## 10.3 Version Pins (reproducibility)

| Component | Version / commit |
|---|---|
| Model | `deepseek-ai/DeepSeek-V4-Flash-0731` @ main `7872f01b1d1fe23eabc4c98b48bffcef5a386062` (at download time) |
| Runtime image | `ghcr.io/anemll/dspark-vllm-gx10:0.1.1`, repo digest `sha256:a83948492cf13df455170fb42885f5ef4db54fefe0feff0f841ecbff464ac9d8` |
| MiaAI repo | `a4ce87a2f47f1be8fe64c297a0cf33a9a5e509aa` (2026-08-04) |
| NCCL | tag `v2.30.7-1` |
| nccl-tests | `717b68318278e93f371d8ffb46b076069d7c7851` (2026-08-03) |
| vLLM (inside image) | `0.25.2.dev0+g752a3a504.d20260714` |
| CUDA | 13.0 (system) |
| Driver | 580.x (kernel module 610.x, API compatible) |
| Network plan | Cluster Assistant: `10.100.192.0/24` + `10.100.193.0/24` |

## 10.4 Package File Inventory

| File | Description |
|---|---|
| `README.md` | Chinese overview and quick start |
| `en/` | English version (this tree) |
| `VARIABLES.md` | masked placeholder reference |
| `docs/DOWNLOADS.md` | full download manifest (official paths/sizes/verification) |
| `docs/01-hardware.md` … `docs/10-appendices.md` | Chinese chapters |
| `en/docs/01-hardware.md` … `en/docs/10-appendices.md` | English chapters |
| `scripts/dsv4-chunkdl.py` | chunked downloader (sha256 + resume) |
| `scripts/resume-downloads.sh` | boot-time auto-resume |
| `scripts/repro-preflight.sh` | environment preflight |
| `scripts/.env.dspark.example` | two-node vLLM config template (masked) |
| `scripts/dspark-vllm-start.sh` | head auto-start wrapper (masked; install to `/usr/local/sbin/` after replacing placeholders) |
| `scripts/dspark-vllm-stop.sh` | head stop wrapper (masked) |
| `scripts/dspark-vllm-ensure.sh` | worker container ensure (masked) |
| `scripts/dspark-vllm.service` | head systemd unit (boot auto-start + failure retry) |
| `scripts/dspark-vllm-worker.service` | worker systemd unit (boot auto-start) |
| `scripts/install-autostart.sh` | one-shot auto-start installer (run on head; installs to both nodes) |

## 10.5 Placeholder Quick Reference

All `<PLACEHOLDER>` definitions live in [VARIABLES.md](../VARIABLES.md). After replacement:

```bash
rg -n "<[A-Z_]+>" .          # confirm nothing is left unreplaced
```
