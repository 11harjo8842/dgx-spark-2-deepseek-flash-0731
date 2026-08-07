# 06 Model Download and Integrity (Restricted-Network Adapted)

## 6.1 Facts

- Model: `deepseek-ai/DeepSeek-V4-Flash-0731` (official 0731 GA, I8/FP4 quantized)
- Size: **166.9 GB** / 74 files / 48 safetensors shards
- Access: **not gated** (no HF token required; logging in lifts rate limits)
- Network reality (China mainland): hf.co direct blocked, proxy ~0 MB/s, Xet refused;
  **hf-mirror.com works directly** (~27 MB/s per connection). On open networks use the official source.

## 6.2 Tooling (head)

```bash
python3 -m venv ~/hf-venv
~/hf-venv/bin/pip install -U huggingface_hub hf_xet httpx
```

## 6.3 Build the Official sha256 Manifest

The manifest maps every file to `path / size / sha256`, where sha256 is the **LFS oid** from the
official HF API. Save it as `~/dsv4-files.json`:

```bash
env -u all_proxy -u ALL_PROXY \
  http_proxy=http://127.0.0.1:1087 https_proxy=http://127.0.0.1:1087 \
  HF_ENDPOINT=https://huggingface.co \
  ~/hf-venv/bin/python - <<'PY'
import json
from huggingface_hub import HfApi
api = HfApi()
files = list(api.list_repo_tree("deepseek-ai/DeepSeek-V4-Flash-0731", recursive=True, expand=True))
out = [{"path": f.path, "size": f.size,
        "sha256": (f.lfs.sha256 if getattr(f, "lfs", None) else None)} for f in files]
json.dump(out, open("/tmp/dsv4-files.json", "w"), indent=1)
print("files:", len(out), "total GB: %.2f" % (sum(x["size"] for x in out) / 1e9))
PY
cp /tmp/dsv4-files.json ~/dsv4-files.json
```

Expected output: `files: 74  total GB: 166.90`, and all 48 shards have a sha256.

## 6.4 Run the Chunked Downloader (head, background)

`../scripts/dsv4-chunkdl.py` features: 20 concurrent × 8MB chunks, 120s per-chunk timeout with 8
retries, resumable (`.chunks.json` sidecar), per-file sha256 verification, automatic re-download on
failure, and a `--verify-only` full pass.

```bash
# foreground with progress
env -u http_proxy -u https_proxy -u all_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY \
  ~/hf-venv/bin/python ~/dsv4-chunkdl.py

# or detached so SSH drops do not interrupt it
nohup setsid env -u http_proxy -u https_proxy -u all_proxy \
  -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY \
  ~/hf-venv/bin/python ~/dsv4-chunkdl.py >> ~/dsv4-chunkdl.log 2>&1 < /dev/null &
# confirm detached: ps -eo pid,ppid,sid,tty,cmd | grep dsv4-chunkdl  → PPID=1, TTY=?
```

Success markers at the end of the log:

```text
ALL_DOWNLOADED
[verify] checked 74/74 files, failures: 0
```

> Measured: hf-mirror direct + 20 workers ≈ **30–40 MB/s**, 166.9 GB in about 1.5–2.5 h.
> If a chunk stalls, the per-chunk timeout retries it automatically — no manual intervention needed.

## 6.5 Sync to the Worker (200G fabric)

The model must exist on both nodes (each TP rank reads all weights). Use the fabric IP over the
200G link with rsync:

```bash
# run on head (detached)
nohup setsid rsync -a --partial --info=progress2 \
  -e "ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null" \
  ~/.cache/huggingface/models/ <USER>@<IP_FABRIC_B>:~/.cache/huggingface/models/ \
  > ~/model-rsync.log 2>&1 < /dev/null &
```

Measured: ≈ **450–500 MB/s**, 166.9 GB in about 6 minutes.

## 6.6 Full Verification on the Worker

Copy the manifest and downloader to the worker, then run `--verify-only`:

```bash
scp ~/dsv4-files.json ~/dsv4-chunkdl.py <USER>@<IP_MGMT_B>:~/
ssh <USER>@<IP_MGMT_B> \
  'nohup setsid env -u http_proxy -u https_proxy -u all_proxy \
   -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY \
   ~/hf-venv/bin/python ~/dsv4-chunkdl.py --verify-only >> ~/dsv4-verify.log 2>&1 < /dev/null &'
```

Expected: `[verify] checked 74/74 files, failures: 0`.

## 6.7 Integrity Notes (pitfalls we hit)

1. The authoritative sha256 comes from the HF API LFS oid — do not trust third-party SHA256SUMS files.
2. The downloader had a real bug: when the server ignored Range and returned 200, file-head bytes
   were written at wrong offsets, corrupting files. Fixed (200 accepted only at offset 0) and
   validated with a 200MB A/B test.
3. Corrupt files are reported as `[hash-fail]` and re-downloaded automatically; `--verify-only`
   re-checks the whole tree at any time.
4. If you use the official `hf download` instead of this script: you **must** set
   `HF_HUB_DISABLE_XET=1` (otherwise Xet returns 403/hangs on restricted networks), and run it
   with `nohup setsid` so it survives SSH drops.

