#!/usr/bin/env python3
import io
import json
import random
import re
import socket
import ssl
import shutil
import sys
import tempfile
import time
import urllib.error
import urllib.request
import zipfile
from datetime import datetime, timezone
from pathlib import Path

OPTIONS_PATH = Path("/data/options.json")
STATE_PATH = Path("/data/provider_subscriber_state.json")
TARGET_DIR = Path("/share/music_assistant/custom_providers")


def log(level: str, msg: str) -> None:
    print(f"[{level}] {msg}", flush=True)


def load_options() -> dict:
    if not OPTIONS_PATH.exists():
        return {}
    try:
        return json.loads(OPTIONS_PATH.read_text(encoding="utf-8"))
    except Exception as exc:
        log("ERROR", f"读取 options.json 失败: {exc}")
        return {}


def load_state() -> dict:
    if not STATE_PATH.exists():
        return {}
    try:
        return json.loads(STATE_PATH.read_text(encoding="utf-8"))
    except Exception:
        return {}


def save_state(state: dict) -> None:
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    STATE_PATH.write_text(
        json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8"
    )


def parse_source(raw: str):
    value = raw.strip()
    if not value or value.startswith("#"):
        return None
    value = re.sub(r"\.git$", "", value)
    pinned_ref = None
    if "@" in value:
        value, pinned_ref = value.rsplit("@", 1)
        pinned_ref = pinned_ref.strip() or None
    if "github.com/" in value:
        m = re.search(r"github\.com[:/]+([^/\s]+)/([^/\s/#]+)", value)
    else:
        m = re.match(r"^([^/\s]+)/([^/\s/#]+)$", value)
    if not m:
        return None
    owner, repo = m.group(1), m.group(2)
    return {"owner": owner, "repo": repo, "pinned_ref": pinned_ref}


def gh_request(url: str, token: str | None) -> bytes:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "ma-provider-subscriber",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read()


def get_default_branch(owner: str, repo: str, token: str | None) -> str:
    data = json.loads(gh_request(f"https://api.github.com/repos/{owner}/{repo}", token))
    return data.get("default_branch") or "main"


def get_latest_release(owner: str, repo: str, token: str | None) -> str | None:
    try:
        data = json.loads(
            gh_request(
                f"https://api.github.com/repos/{owner}/{repo}/releases/latest", token
            )
        )
        tag = (data.get("tag_name") or "").strip()
        return tag or None
    except urllib.error.HTTPError as exc:
        if exc.code in (404, 403):
            return None
        raise


def resolve_ref(owner: str, repo: str, parsed: dict, strategy: str, token: str | None) -> str:
    if parsed["pinned_ref"]:
        return parsed["pinned_ref"]
    if strategy == "latest_release":
        tag = get_latest_release(owner, repo, token)
        if tag:
            return tag
    return get_default_branch(owner, repo, token)


def resolve_sha(owner: str, repo: str, ref: str, token: str | None) -> str:
    data = json.loads(
        gh_request(f"https://api.github.com/repos/{owner}/{repo}/commits/{ref}", token)
    )
    sha = (data.get("sha") or "").strip()
    if not sha:
        raise RuntimeError("未获取到 commit sha")
    return sha


def download_zip(owner: str, repo: str, ref: str, token: str | None) -> bytes:
    return gh_request(f"https://api.github.com/repos/{owner}/{repo}/zipball/{ref}", token)


def is_retryable_error(exc: Exception) -> bool:
    retryable_types = (
        urllib.error.URLError,
        TimeoutError,
        socket.timeout,
        ConnectionResetError,
        ssl.SSLError,
    )
    return isinstance(exc, retryable_types)


def backoff_sleep_seconds(base_seconds: int, attempt_index: int) -> int:
    # attempt_index starts at 1.
    raw = base_seconds * (2 ** (attempt_index - 1))
    capped = min(raw, 1800)
    jitter = int(random.uniform(0, base_seconds * 0.3))
    return capped + jitter


def find_provider_dirs(root: Path) -> list[Path]:
    provider_dirs = []
    for manifest in root.rglob("manifest.json"):
        if ".git" in manifest.parts or ".github" in manifest.parts:
            continue
        provider_dir = manifest.parent
        if provider_dir.joinpath("__init__.py").exists():
            provider_dirs.append(provider_dir)
    uniq = []
    seen = set()
    for p in provider_dirs:
        if p in seen:
            continue
        seen.add(p)
        uniq.append(p)
    return uniq


def sync_once(options: dict, state: dict) -> dict:
    sources = options.get("sources") or []
    strategy = options.get("update_strategy", "latest_release")
    prune_removed = bool(options.get("prune_removed", False))
    token = (options.get("github_token") or "").strip() or None
    retry_attempts = int(options.get("retry_attempts", 3))
    retry_attempts = max(1, min(5, retry_attempts))
    retry_base_seconds = int(options.get("retry_base_seconds", 180))
    retry_base_seconds = max(60, min(1800, retry_base_seconds))

    TARGET_DIR.mkdir(parents=True, exist_ok=True)
    next_state = {"sources": {}}
    expected_providers = set()

    if not sources:
        log("INFO", "未配置 sources，跳过订阅更新。")
        return next_state

    for raw in sources:
        parsed = parse_source(str(raw))
        if not parsed:
            log("WARNING", f"跳过无效 source: {raw}")
            continue

        owner = parsed["owner"]
        repo = parsed["repo"]
        source_key = f"{owner}/{repo}"

        try:
            def run_for_source():
                ref = resolve_ref(owner, repo, parsed, strategy, token)
                sha = resolve_sha(owner, repo, ref, token)
                prev = (state.get("sources") or {}).get(source_key, {})
                if prev.get("sha") == sha:
                    return {"status": "no_change", "ref": ref, "sha": sha, "prev": prev}

                archive = download_zip(owner, repo, ref, token)
                with tempfile.TemporaryDirectory(prefix="provider_subscriber_") as tmp:
                    tmp_root = Path(tmp)
                    with zipfile.ZipFile(io.BytesIO(archive)) as zf:
                        zf.extractall(tmp_root)
                    roots = [p for p in tmp_root.iterdir() if p.is_dir()]
                    if not roots:
                        raise RuntimeError("repository archive is empty")
                    provider_dirs = find_provider_dirs(roots[0])
                    if not provider_dirs:
                        raise RuntimeError("no provider folders found (manifest.json + __init__.py)")

                    installed = []
                    for provider_dir in provider_dirs:
                        name = provider_dir.name
                        target = TARGET_DIR / name
                        if target.exists():
                            shutil.rmtree(target)
                        shutil.copytree(provider_dir, target)
                        marker = target / ".subscriber_source"
                        marker.write_text(
                            f"source={source_key}\nref={ref}\nsha={sha}\n",
                            encoding="utf-8",
                        )
                        installed.append(name)
                    return {"status": "updated", "ref": ref, "sha": sha, "installed": installed}

            result = None
            last_exc = None
            for attempt in range(1, retry_attempts + 1):
                try:
                    result = run_for_source()
                    break
                except Exception as exc:
                    last_exc = exc
                    if not is_retryable_error(exc) or attempt >= retry_attempts:
                        raise
                    wait_seconds = backoff_sleep_seconds(retry_base_seconds, attempt)
                    log(
                        "WARNING",
                        f"{source_key} network error on attempt {attempt}/{retry_attempts}: {exc}. "
                        f"retry in {wait_seconds}s",
                    )
                    time.sleep(wait_seconds)
            if result is None and last_exc:
                raise last_exc

            if result["status"] == "no_change":
                ref = result["ref"]
                prev = result["prev"]
                log("INFO", f"{source_key}@{ref} no update, skipped.")
                next_state["sources"][source_key] = prev
                for name in prev.get("providers", []):
                    expected_providers.add(name)
                continue

            ref = result["ref"]
            sha = result["sha"]
            installed = result["installed"]
            for name in installed:
                expected_providers.add(name)

            next_state["sources"][source_key] = {
                "ref": ref,
                "sha": sha,
                "providers": sorted(installed),
                "synced_at": datetime.now(timezone.utc).isoformat(),
            }
            log("INFO", f"{source_key}@{ref} updated, providers: {', '.join(installed)}")
        except Exception as exc:
            log("ERROR", f"{source_key} update failed: {exc}")
            prev = (state.get("sources") or {}).get(source_key)
            if prev:
                next_state["sources"][source_key] = prev
                for name in prev.get("providers", []):
                    expected_providers.add(name)

    if prune_removed:
        for p in TARGET_DIR.iterdir():
            if not p.is_dir():
                continue
            marker = p / ".subscriber_source"
            if marker.exists() and p.name not in expected_providers:
                shutil.rmtree(p)
                log("INFO", f"已清理下线 provider: {p.name}")

    return next_state


def main() -> int:
    while True:
        options = load_options()
        state = load_state()
        run_on_start = bool(options.get("run_on_start", True))
        run_forever = bool(options.get("run_forever", True))
        interval_minutes = int(options.get("interval_minutes", 360))
        interval_seconds = max(600, interval_minutes * 60)

        if run_on_start or not STATE_PATH.exists():
            next_state = sync_once(options, state)
            save_state(next_state)
        else:
            log("INFO", "run_on_start=false，启动时不执行更新。")

        if not run_forever:
            log("INFO", "run_forever=false，执行完成后退出。")
            return 0

        log("INFO", f"next check in {interval_seconds} seconds.")
        time.sleep(interval_seconds)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        log("INFO", "收到中断信号，退出。")
        raise SystemExit(0)
