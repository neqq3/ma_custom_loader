#!/usr/bin/env python3
import io
import json
import os
import random
import re
import shutil
import socket
import ssl
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_OPTIONS_PATHS = [Path("/data/options.json"), Path("/config/options.json")]
DEFAULT_STATE_PATH = Path("/data/provider_subscriber_state.json")
DEFAULT_TARGET_DIR = Path("/share/music_assistant/custom_providers")


def log(level: str, msg: str) -> None:
    print(f"[{level}] {msg}", flush=True)


def resolve_options_path() -> Path | None:
    env_raw = os.environ.get("SUBSCRIBER_CONFIG_PATH", "").strip()
    env_path = Path(env_raw) if env_raw else None
    if env_path:
        return env_path
    for path in DEFAULT_OPTIONS_PATHS:
        if path.exists():
            return path
    return None


def resolve_state_path() -> Path:
    value = os.environ.get("SUBSCRIBER_STATE_PATH", "").strip()
    return Path(value) if value else DEFAULT_STATE_PATH


def resolve_target_dir() -> Path:
    value = os.environ.get("SUBSCRIBER_TARGET_DIR", "").strip()
    return Path(value) if value else DEFAULT_TARGET_DIR


def load_options() -> dict:
    options_path = resolve_options_path()
    if options_path is None:
        log("WARNING", "No options.json found in /data or /config, using empty config.")
        return {}
    if not options_path.exists():
        log("WARNING", f"Config file does not exist: {options_path}")
        return {}
    try:
        data = json.loads(options_path.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            raise ValueError("top-level JSON must be an object")
        log("INFO", f"Loaded config from {options_path}")
        return data
    except Exception as exc:
        log("ERROR", f"Failed to read config {options_path}: {exc}")
        return {}


def load_state(state_path: Path) -> dict:
    if not state_path.exists():
        return {}
    try:
        return json.loads(state_path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def save_state(state_path: Path, state: dict) -> None:
    state_path.parent.mkdir(parents=True, exist_ok=True)
    state_path.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")


def parse_source(raw: str):
    value = raw.strip()
    if not value or value.startswith("#"):
        return None
    value = re.sub(r"\.git$", "", value)
    pinned_ref = None
    if "@" in value:
        value, pinned_ref = value.rsplit("@", 1)
        pinned_ref = pinned_ref.strip() or None

    provider = "github"
    match = None
    if "github.com/" in value:
        provider = "github"
        match = re.search(r"github\.com[:/]+([^/\s]+)/([^/\s/#]+)", value)
    elif "gitee.com/" in value:
        provider = "gitee"
        match = re.search(r"gitee\.com[:/]+([^/\s]+)/([^/\s/#]+)", value)
    elif "gitcode.com/" in value:
        provider = "gitcode"
        match = re.search(r"gitcode\.com[:/]+([^/\s]+)/([^/\s/#]+)", value)
    else:
        # Backward compatible: owner/repo defaults to GitHub.
        match = re.match(r"^([^/\s]+)/([^/\s/#]+)$", value)

    if not match:
        return None

    return {
        "provider": provider,
        "owner": match.group(1),
        "repo": match.group(2),
        "pinned_ref": pinned_ref,
    }


def build_github_api_url(path: str, proxy: str) -> str:
    base_url = f"https://api.github.com{path}"
    if not proxy:
        return base_url
    prefix = proxy.rstrip("/") + "/"
    return f"{prefix}{base_url}"


def build_provider_api_url(provider: str, path: str, proxy: str = "") -> str:
    if provider == "github":
        return build_github_api_url(path, proxy)
    if provider == "gitee":
        return f"https://gitee.com/api/v5{path}"
    if provider == "gitcode":
        return f"https://api.gitcode.com/api/v5{path}"
    raise ValueError(f"Unsupported provider: {provider}")


def http_request(url: str, token: str | None) -> bytes:
    headers = {"Accept": "application/json", "User-Agent": "ma-provider-subscriber"}
    # Only attach token to direct GitHub API requests to avoid leaking credentials to proxy hosts.
    if token and url.startswith("https://api.github.com/"):
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read()


def get_default_branch(provider: str, owner: str, repo: str, token: str | None, proxy: str = "") -> str:
    url = build_provider_api_url(provider, f"/repos/{owner}/{repo}", proxy)
    data = json.loads(http_request(url, token))
    return data.get("default_branch") or "main"


def get_latest_release(provider: str, owner: str, repo: str, token: str | None, proxy: str = "") -> str | None:
    try:
        url = build_provider_api_url(provider, f"/repos/{owner}/{repo}/releases/latest", proxy)
        data = json.loads(http_request(url, token))
        tag = (data.get("tag_name") or "").strip()
        return tag or None
    except urllib.error.HTTPError as exc:
        if exc.code in (404, 403):
            return None
        raise


def resolve_ref(provider: str, owner: str, repo: str, parsed: dict, strategy: str, token: str | None, proxy: str = "") -> str:
    if parsed["pinned_ref"]:
        return parsed["pinned_ref"]
    if strategy == "latest_release":
        latest = get_latest_release(provider, owner, repo, token, proxy)
        if latest:
            return latest
    return get_default_branch(provider, owner, repo, token, proxy)


def resolve_sha(provider: str, owner: str, repo: str, ref: str, token: str | None, proxy: str = "") -> str:
    url = build_provider_api_url(provider, f"/repos/{owner}/{repo}/commits/{ref}", proxy)
    data = json.loads(http_request(url, token))
    sha = (data.get("sha") or "").strip()
    if not sha:
        raise RuntimeError("commit sha is empty")
    return sha


def is_zip_bytes(data: bytes) -> bool:
    return data.startswith((b"PK\x03\x04", b"PK\x05\x06", b"PK\x07\x08"))


def archive_urls(provider: str, owner: str, repo: str, ref: str, proxy: str = "") -> list[str]:
    ref_q = urllib.parse.quote(ref, safe="")
    if provider == "github":
        return [build_provider_api_url(provider, f"/repos/{owner}/{repo}/zipball/{ref}", proxy)]
    if provider == "gitee":
        return [
            build_provider_api_url(provider, f"/repos/{owner}/{repo}/zipball/{ref}", proxy),
            f"https://gitee.com/{owner}/{repo}/repository/archive/{ref_q}.zip",
        ]
    if provider == "gitcode":
        return [
            build_provider_api_url(provider, f"/repos/{owner}/{repo}/zipball/{ref}", proxy),
            f"https://gitcode.com/{owner}/{repo}/repository/archive/{ref_q}.zip",
        ]
    raise ValueError(f"Unsupported provider: {provider}")

def repo_clone_url(provider: str, owner: str, repo: str) -> str:
    host_map = {
        "github": "github.com",
        "gitee": "gitee.com",
        "gitcode": "gitcode.com",
    }
    host = host_map.get(provider)
    if not host:
        raise ValueError(f"Unsupported provider: {provider}")
    return f"https://{host}/{owner}/{repo}.git"


def download_zip_via_git_clone(provider: str, owner: str, repo: str, ref: str) -> bytes:
    with tempfile.TemporaryDirectory(prefix="provider_git_clone_") as tmp:
        repo_dir = Path(tmp) / "repo"
        subprocess.run(
            ["git", "clone", "--depth", "1", "--branch", ref, repo_clone_url(provider, owner, repo), str(repo_dir)],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

        zip_root = f"{repo}-{ref}"
        buf = io.BytesIO()
        with zipfile.ZipFile(buf, mode="w", compression=zipfile.ZIP_DEFLATED) as zf:
            for path in repo_dir.rglob("*"):
                if ".git" in path.parts:
                    continue
                arcname = f"{zip_root}/{path.relative_to(repo_dir).as_posix()}"
                if path.is_dir():
                    zf.writestr(f"{arcname}/", b"")
                else:
                    zf.write(path, arcname)
        return buf.getvalue()



def download_zip(provider: str, owner: str, repo: str, ref: str, token: str | None, proxy: str = "") -> bytes:
    errors: list[str] = []
    for url in archive_urls(provider, owner, repo, ref, proxy):
        try:
            payload = http_request(url, token)
            if is_zip_bytes(payload):
                return payload
            preview = payload[:120].decode("utf-8", errors="ignore").replace("\n", " ").replace("\r", " ")
            errors.append(f"{url} returned non-zip payload: {preview}")
        except Exception as exc:
            errors.append(f"{url} -> {exc}")
    if provider in ("gitee", "gitcode"):
        try:
            return download_zip_via_git_clone(provider, owner, repo, ref)
        except Exception as exc:
            errors.append(f"git-clone fallback -> {exc}")
    raise RuntimeError("archive download failed; " + " | ".join(errors))

def is_retryable_error(exc: Exception) -> bool:
    return isinstance(exc, (urllib.error.URLError, TimeoutError, socket.timeout, ConnectionResetError, ssl.SSLError))


def backoff_sleep_seconds(base_seconds: int, attempt_index: int) -> int:
    base = min(base_seconds * (2 ** (attempt_index - 1)), 1800)
    jitter = int(random.uniform(0, base_seconds * 0.3))
    return base + jitter


def find_provider_dirs(root: Path) -> list[Path]:
    result: list[Path] = []
    seen: set[Path] = set()
    for manifest in root.rglob("manifest.json"):
        if ".git" in manifest.parts or ".github" in manifest.parts:
            continue
        provider_dir = manifest.parent
        if not provider_dir.joinpath("__init__.py").exists():
            continue
        if provider_dir in seen:
            continue
        seen.add(provider_dir)
        result.append(provider_dir)
    return result


def sync_once(options: dict, state: dict, target_dir: Path) -> dict:
    sources = options.get("sources") or []
    strategy = options.get("update_strategy", "latest_release")
    prune_removed = bool(options.get("prune_removed", False))
    token = (options.get("github_token") or "").strip() or None
    proxy = (options.get("github_proxy") or "").strip()
    retry_attempts = max(1, min(5, int(options.get("retry_attempts", 3))))
    retry_base_seconds = max(60, min(1800, int(options.get("retry_base_seconds", 180))))

    if proxy:
        log("INFO", f"GitHub proxy enabled: {proxy}")

    target_dir.mkdir(parents=True, exist_ok=True)
    next_state = {"sources": {}}
    expected_providers: set[str] = set()

    if not sources:
        log("INFO", "No sources configured, skip this cycle.")
        return next_state

    for raw in sources:
        parsed = parse_source(str(raw))
        if not parsed:
            log("WARNING", f"Skip invalid source: {raw}")
            continue

        owner = parsed["owner"]
        repo = parsed["repo"]
        provider = parsed["provider"]
        source_key = f"{provider}:{owner}/{repo}"
        def run_for_source():
            effective_proxy = proxy if provider == "github" else ""
            effective_token = token if provider == "github" else None
            ref = resolve_ref(provider, owner, repo, parsed, strategy, effective_token, effective_proxy)
            sha = resolve_sha(provider, owner, repo, ref, effective_token, effective_proxy)
            prev = (state.get("sources") or {}).get(source_key, {})
            if prev.get("sha") == sha:
                return {"status": "no_change", "ref": ref, "sha": sha, "prev": prev}

            archive = download_zip(provider, owner, repo, ref, effective_token, effective_proxy)
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
                installed: list[str] = []
                for provider_dir in provider_dirs:
                    name = provider_dir.name
                    target = target_dir / name
                    if target.exists():
                        shutil.rmtree(target)
                    shutil.copytree(provider_dir, target)
                    marker = target / ".subscriber_source"
                    marker.write_text(f"source={source_key}\nref={ref}\nsha={sha}\n", encoding="utf-8")
                    installed.append(name)
                return {"status": "updated", "ref": ref, "sha": sha, "installed": installed}

        try:
            result = None
            for attempt in range(1, retry_attempts + 1):
                try:
                    result = run_for_source()
                    break
                except Exception as exc:
                    if not is_retryable_error(exc) or attempt >= retry_attempts:
                        raise
                    wait_seconds = backoff_sleep_seconds(retry_base_seconds, attempt)
                    log("WARNING", f"{source_key} network error attempt {attempt}/{retry_attempts}: {exc}; retry in {wait_seconds}s")
                    if provider == "github" and not proxy and is_retryable_error(exc):
                        log("WARNING", "[Hint] If GitHub is slow in your region, set 'github_proxy' in add-on config.")
                    time.sleep(wait_seconds)

            if result is None:
                raise RuntimeError("unexpected empty result")

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
        for item in target_dir.iterdir():
            if not item.is_dir():
                continue
            marker = item / ".subscriber_source"
            if marker.exists() and item.name not in expected_providers:
                shutil.rmtree(item)
                log("INFO", f"Pruned removed managed provider: {item.name}")

    return next_state


def main() -> int:
    state_path = resolve_state_path()
    target_dir = resolve_target_dir()
    log("INFO", f"Using state path: {state_path}")
    log("INFO", f"Using target dir: {target_dir}")

    while True:
        options = load_options()
        state = load_state(state_path)
        run_on_start = bool(options.get("run_on_start", True))
        run_forever = bool(options.get("run_forever", True))
        interval_minutes = int(options.get("interval_minutes", 360))
        interval_seconds = max(600, interval_minutes * 60)

        if run_on_start or not state_path.exists():
            next_state = sync_once(options, state, target_dir)
            save_state(state_path, next_state)
        else:
            log("INFO", "run_on_start=false, skip startup run.")

        if not run_forever:
            log("INFO", "run_forever=false, exit after this cycle.")
            return 0

        log("INFO", f"Next check in {interval_seconds} seconds.")
        time.sleep(interval_seconds)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        log("INFO", "Interrupted, exiting.")
        raise SystemExit(0)
