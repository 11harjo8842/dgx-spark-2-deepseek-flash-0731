#!/usr/bin/env python3
# =============================================================================
# 自研分块下载器（适配不稳定网络）
# - 20 并发 × 8MB 分块，HTTP Range 请求
# - 每块 120s 超时 + 8 次重试（防断流假死）
# - 断点续传（sidecar: <file>.chunks.json 记录已完成块）
# - 文件级 sha256 校验（对照官方 LFS 清单），失败自动整文件重下
# - --verify-only 全量复核模式
# 依赖：python3 + httpx（pip install httpx）
# 清单：~/dsv4-files.json（74 个文件的 path/size/sha256，来自 HF 官方 API）
# =============================================================================
import json, os, sys, time, hashlib, threading
from concurrent.futures import ThreadPoolExecutor, as_completed
import httpx

REPO = "deepseek-ai/DeepSeek-V4-Flash-0731"
BASE = f"https://hf-mirror.com/{REPO}/resolve/main/"
DEST = os.path.expanduser("~/.cache/huggingface/models/DeepSeek-V4-Flash-0731")
MANIFEST = os.path.expanduser("~/dsv4-files.json")
CHUNK = 8 * 1024 * 1024
WORKERS = 20
TIMEOUT = 120.0
RETRIES = 8

files = json.load(open(MANIFEST))
files.sort(key=lambda x: -x["size"])
files = [f for f in files if f["size"] > 0]

client = httpx.Client(follow_redirects=True, timeout=TIMEOUT,
                      headers={"User-Agent": "Mozilla/5.0"},
                      transport=httpx.HTTPTransport(verify=True))
lock = threading.Lock()
stats = {"done": 0, "start": time.time()}

def dl_chunk(path, off, size):
    url = BASE + path
    headers = {"Range": f"bytes={off}-{off+size-1}"}
    last = None
    for attempt in range(RETRIES):
        try:
            r = client.get(url, headers=headers)
            if r.status_code == 206:
                data = r.content
            elif r.status_code == 200:
                # 200 means the server ignored our Range header.
                # Only valid for the first chunk of a small file; otherwise
                # writing file-head bytes at a wrong offset corrupts the file.
                if off != 0 or len(r.content) < size:
                    raise RuntimeError(f"server ignored range (200, off={off}, len={len(r.content)})")
                data = r.content[:size]
            else:
                raise RuntimeError(f"status {r.status_code}")
            if len(data) != size:
                raise RuntimeError(f"short {len(data)}<{size}")
            fp = os.path.join(DEST, path)
            with open(fp, "r+b") as f:
                f.seek(off); f.write(data)
            with lock:
                stats["done"] += size
            return True
        except Exception as e:
            last = e
            time.sleep(min(2 * (attempt + 1), 20))
    print(f"[drop] {path}@{off}: {last}", flush=True)
    return False

def sidecar(path):
    return os.path.join(DEST, path + ".chunks.json")

def verify_sha(path, sha, size):
    if not sha: return True
    h = hashlib.sha256()
    fp = os.path.join(DEST, path)
    with open(fp, "rb") as f:
        while True:
            b = f.read(8 * 1024 * 1024)
            if not b: break
            h.update(b)
    ok = h.hexdigest() == sha
    if not ok:
        print(f"[hash-fail] {path} expected {sha[:16]} got {h.hexdigest()[:16]}", flush=True)
    return ok

def verify_pass(verbose=True):
    """Full integrity pass: sha256 for LFS files, exact size for the rest."""
    bad, checked = [], 0
    for m in files:
        path, size, sha = m["path"], m["size"], m["sha256"]
        fp = os.path.join(DEST, path)
        if not os.path.exists(fp) or os.path.getsize(fp) != size:
            bad.append((path, "missing/size"))
            continue
        if sha:
            checked += 1
            if not verify_sha(path, sha, size):
                bad.append((path, "sha256"))
        else:
            checked += 1
            try:
                if path.endswith(".json"):
                    json.load(open(fp))
            except Exception as e:
                bad.append((path, f"json:{e}"))
    print(f"[verify] checked {checked}/{len(files)} files, failures: {len(bad)}", flush=True)
    for b in bad[:20]:
        print(f"[verify-FAIL] {b[0]} ({b[1]})", flush=True)
    return len(bad) == 0

def dl_file(meta):
    path, size, sha = meta["path"], meta["size"], meta["sha256"]
    fp = os.path.join(DEST, path)
    os.makedirs(os.path.dirname(fp), exist_ok=True)
    if os.path.exists(fp) and os.path.getsize(fp) == size and verify_sha(path, sha, size):
        print(f"[skip] {path}", flush=True)
        return True
    with open(fp, "wb") as f:
        f.truncate(size)
    sc = sidecar(path)
    done = set()
    if os.path.exists(sc):
        try: done = set(json.load(open(sc)))
        except Exception: done = set()
    chunks = [(off, min(CHUNK, size - off)) for off in range(0, size, CHUNK)]
    todo = [(o, s) for o, s in chunks if o not in done]
    t0 = time.time()
    with ThreadPoolExecutor(max_workers=WORKERS) as ex:
        futs = {ex.submit(dl_chunk, path, o, s): o for o, s in todo}
        n_ok = len(done)
        for fut in as_completed(futs):
            off = futs[fut]
            try: ok = fut.result()
            except Exception: ok = False
            if ok:
                done.add(off); n_ok += 1
                if n_ok % 40 == 0:
                    with lock:
                        json.dump(sorted(done), open(sc, "w"))
                        spd = stats["done"] / max(time.time() - stats["start"], 1)
                    print(f"[prog] {path} {n_ok}/{len(chunks)} chunks | overall {spd/1e6:.1f} MB/s", flush=True)
            else:
                print(f"[chunk-fail] {path}@{off}", flush=True)
    with lock:
        json.dump(sorted(done), open(sc, "w"))
    if len(done) != len(chunks):
        print(f"[incomplete] {path} {len(done)}/{len(chunks)}", flush=True)
        return False
    if verify_sha(path, sha, size):
        try: os.remove(sc)
        except Exception: pass
        print(f"[OK] {path} ({size/1e9:.2f} GB)", flush=True)
        return True
    try: os.remove(sc)
    except Exception: pass
    return False

def main():
    pending = list(files)
    for rnd in range(1, 11):
        if not pending:
            print("ALL_DOWNLOADED", flush=True); return 0
        print(f"=== round {rnd}: {len(pending)} files ===", flush=True)
        nxt = []
        for m in pending:
            if not dl_file(m):
                nxt.append(m)
        pending = nxt
        if pending:
            print(f"=== {len(pending)} files still pending, sleeping 20s ===", flush=True)
            time.sleep(20)
    print("STILL_PENDING", [m["path"] for m in pending], flush=True)
    return 1

if "--verify-only" in sys.argv:
    sys.exit(0 if verify_pass() else 1)

rc = main()
if rc == 0:
    rc = 0 if verify_pass() else 1
sys.exit(rc)

