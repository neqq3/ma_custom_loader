#!/usr/bin/env bash
set -euo pipefail

echo "=== Music Assistant Custom Loader ==="

CUSTOM_DIR="${CUSTOM_PROVIDERS_DIR:-/share/music_assistant/custom_providers}"
echo "Checking custom providers in: ${CUSTOM_DIR}"

read_option() {
  local opt_type="$1"
  local opt_key="$2"
  local opt_default="$3"
  python3 - "$opt_type" "$opt_key" "$opt_default" <<'PY'
import json
import sys
from pathlib import Path

opt_type = sys.argv[1]
opt_key = sys.argv[2]
opt_default = sys.argv[3]
options_path = Path("/data/options.json")

if not options_path.exists():
    print(opt_default)
    raise SystemExit(0)

try:
    data = json.loads(options_path.read_text(encoding="utf-8"))
except Exception:
    print(opt_default)
    raise SystemExit(0)

value = data.get(opt_key, opt_default)

if opt_type == "bool":
    if isinstance(value, bool):
        print("true" if value else "false")
    elif isinstance(value, str):
        print("true" if value.lower() in {"1", "true", "yes", "on"} else "false")
    else:
        print("false")
else:
    print(str(value))
PY
}

is_true() {
  local value="${1,,}"
  [[ "${value}" == "1" || "${value}" == "true" || "${value}" == "yes" || "${value}" == "on" ]]
}

import_official_config="$(read_option bool import_official_config false)"
auto_detect_official_slug="$(read_option bool auto_detect_official_slug true)"
official_slug="$(read_option str official_slug "")"
force_overwrite_on_import="$(read_option bool force_overwrite_on_import false)"
strict_provider_injection="$(read_option bool strict_provider_injection false)"
migration_marker="/data/.official_import_done"

find_source_dir_by_slug() {
  local slug="$1"
  local base=""
  local candidate=""
  local path=""
  for base in /addon_configs /data/addons/data /mnt/data/supervisor/addons/data; do
    [[ -d "${base}" ]] || continue

    # Exact folder name match.
    candidate="${base}/${slug}"
    if [[ -d "${candidate}" ]]; then
      echo "${candidate}"
      return 0
    fi

    # Common prefixed form used by some environments.
    candidate="${base}/addon_${slug}"
    if [[ -d "${candidate}" ]]; then
      echo "${candidate}"
      return 0
    fi

    # Repo-hash prefix form like addon_<repohash>_<slug>.
    for path in "${base}"/addon_*_"${slug}"; do
      if [[ -d "${path}" ]]; then
        echo "${path}"
        return 0
      fi
    done
  done
  return 1
}

discover_slug_from_supervisor() {
  if [[ -z "${SUPERVISOR_TOKEN:-}" ]]; then
    echo "Auto-detect: SUPERVISOR_TOKEN is missing, skip Supervisor API lookup." >&2
    return 1
  fi
  SUPERVISOR_TOKEN="${SUPERVISOR_TOKEN}" python3 - <<'PY'
import json
import os
import re
import urllib.error
import urllib.request

try:
    token = os.environ["SUPERVISOR_TOKEN"]
except KeyError:
    raise SystemExit(1)

req = urllib.request.Request(
    "http://supervisor/addons",
    headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    },
)
try:
    with urllib.request.urlopen(req, timeout=8) as resp:
        payload = json.loads(resp.read().decode("utf-8"))
except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, ValueError):
    raise SystemExit(1)

addons = payload.get("data", {}).get("addons", [])
for addon in addons:
    slug = str(addon.get("slug", ""))
    if not slug:
        continue
    lower_slug = slug.lower()
    if "music_assistant" not in lower_slug:
        continue
    if "custom_loader" in lower_slug or "custom-loader" in lower_slug:
        continue
    if re.search(r"(^|_)beta($|_)", lower_slug):
        continue
    print(slug)
    raise SystemExit(0)

raise SystemExit(1)
PY
}

log_import_probe() {
  local base=""
  local found_any="false"
  for base in /addon_configs /data/addons/data /mnt/data/supervisor/addons/data; do
    if [[ -d "${base}" ]]; then
      found_any="true"
      echo "Import probe: found base dir ${base}"
      find "${base}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed -n '1,8p' | while read -r entry; do
        echo "  - $(basename "${entry}")"
      done
    else
      echo "Import probe: base dir not visible ${base}"
    fi
  done
  if [[ "${found_any}" != "true" ]]; then
    echo "Import probe: no add-on data base directories are visible in this container."
  fi
}

discover_slug_from_filesystem() {
  local base=""
  local path=""
  local slug=""
  shopt -s nullglob
  for base in /addon_configs /data/addons/data /mnt/data/supervisor/addons/data; do
    [[ -d "${base}" ]] || continue
    for path in "${base}"/*; do
      [[ -d "${path}" ]] || continue
      slug="$(basename "${path}")"
      case "${slug,,}" in
        *music_assistant*)
          if [[ "${slug,,}" != *custom_loader* && "${slug,,}" != *custom-loader* ]]; then
            echo "${slug}"
            shopt -u nullglob
            return 0
          fi
          ;;
      esac
    done
  done
  shopt -u nullglob
  return 1
}


import_from_supervisor_backup() {
  local addon_slug="$1"
  local backup_root="$2"
  local force_flag="$3"

  if [[ -z "${addon_slug}" ]]; then
    echo "Supervisor backup import: empty addon slug, skip."
    return 1
  fi
  if [[ -z "${SUPERVISOR_TOKEN:-}" ]]; then
    echo "Supervisor backup import: SUPERVISOR_TOKEN is missing, skip."
    return 1
  fi

  echo "Trying migration via Supervisor Backup API for addon slug: ${addon_slug}"
  if ! ADDON_SLUG="${addon_slug}" BACKUP_ROOT="${backup_root}" FORCE_IMPORT="${force_flag}" SUPERVISOR_TOKEN="${SUPERVISOR_TOKEN}" python3 - <<'PY'
import io
import json
import os
import pathlib
import shutil
import tarfile
import tempfile
import urllib.request

def request_json(url: str, token: str, method: str = "GET", body: dict | None = None) -> dict:
    data = None
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    if body is not None:
        data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=120) as resp:
        payload = json.loads(resp.read().decode("utf-8"))
    if payload.get("result") != "ok":
        raise RuntimeError(f"Supervisor API returned non-ok result for {url}")
    return payload

def download_backup(url: str, token: str) -> bytes:
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"}, method="GET")
    with urllib.request.urlopen(req, timeout=300) as resp:
        return resp.read()

def copy_tree(src: pathlib.Path, dst: pathlib.Path) -> None:
    for item in src.iterdir():
        if item.name == "options.json":
            continue
        target = dst / item.name
        if item.is_dir():
            if target.exists() and target.is_file():
                target.unlink()
            target.mkdir(parents=True, exist_ok=True)
            copy_tree(item, target)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(item, target)

token = os.environ["SUPERVISOR_TOKEN"]
addon_slug = os.environ["ADDON_SLUG"]
backup_root = pathlib.Path(os.environ["BACKUP_ROOT"])
force_import = os.environ.get("FORCE_IMPORT", "false").lower() in {"1", "true", "yes", "on"}
target_data = pathlib.Path("/data")

created = request_json(
    "http://supervisor/backups/new/partial",
    token,
    method="POST",
    body={
        "name": "[MA Custom Loader] \u539f\u7248MA\u914d\u7f6e(\u8fc1\u79fb\u524d\u81ea\u52a8\u5907\u4efd) / Original Backup",
        "addons": [addon_slug],
        "homeassistant": False,
    },
)
backup_slug = str(created.get("data", {}).get("slug", "")).strip()
if not backup_slug:
    raise RuntimeError("Failed to create backup: missing backup slug")

archive_bytes = download_backup(f"http://supervisor/backups/{backup_slug}/download", token)
if not archive_bytes:
    raise RuntimeError("Downloaded backup archive is empty")

backup_root.mkdir(parents=True, exist_ok=True)
(backup_root / "supervisor_backup_slug.txt").write_text(backup_slug + "\n", encoding="utf-8")

with tempfile.TemporaryDirectory(prefix="ma_migrate_") as tmp:
    tmp_path = pathlib.Path(tmp)
    outer_dir = tmp_path / "outer"
    outer_dir.mkdir(parents=True, exist_ok=True)
    with tarfile.open(fileobj=io.BytesIO(archive_bytes), mode="r:*") as tf:
        tf.extractall(outer_dir)

    nested_archives = [
        p for p in outer_dir.rglob("*")
        if p.is_file() and (p.name.endswith(".tar") or p.name.endswith(".tar.gz") or p.name.endswith(".tgz"))
    ]
    if not nested_archives:
        raise RuntimeError("No nested addon archive found in backup payload")
    nested_archives.sort(key=lambda p: (addon_slug.lower() not in p.name.lower(), len(p.name)))
    addon_archive = nested_archives[0]

    addon_dir = tmp_path / "addon"
    addon_dir.mkdir(parents=True, exist_ok=True)
    with tarfile.open(addon_archive, mode="r:*") as tf:
        tf.extractall(addon_dir)

    source_data = addon_dir / "data"
    if not source_data.is_dir():
        source_data = addon_dir
    if not any(source_data.iterdir()):
        raise RuntimeError("Extracted addon data is empty")

    if force_import:
        for child in target_data.iterdir():
            if child.name in {"options.json", ".official_import_done"}:
                continue
            if child.is_dir():
                shutil.rmtree(child)
            else:
                child.unlink(missing_ok=True)

    copy_tree(source_data, target_data)
    (backup_root / "supervisor_import_meta.json").write_text(
        json.dumps(
            {
                "method": "supervisor_backup_api",
                "addon_slug": addon_slug,
                "backup_slug": backup_slug,
                "archive_name": addon_archive.name,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
print(f"Supervisor backup import succeeded: addon={addon_slug}")
PY
  then
    echo "WARNING: Supervisor backup import failed."
    return 1
  fi
  return 0
}

write_migration_index() {
  local backup_root="$1"
  local source_slug="$2"
  local method="$3"
  local official_backup_slug="$4"

  cat > "${backup_root}/README.txt" <<EOF
Music Assistant migration index

Timestamp: $(date '+%Y-%m-%d %H:%M:%S')
Source add-on slug: ${source_slug}
Migration method: ${method}
Official backup slug (HA /backup): ${official_backup_slug}

Notes:
- Real restore archives are managed by Home Assistant Supervisor under /backup.
- This folder stores migration metadata and local troubleshooting snapshots only.
- Deleting this folder does NOT delete the real HA backup archive in /backup.
- Local loader snapshot before import: ${backup_root}/loader_before_import

Rollback hints:
- Restore official MA state: restore the HA backup using the backup slug above.
- Restore loader pre-import local snapshot: copy files from loader_before_import back to /data.
EOF
}

if is_true "${import_official_config}"; then
  if [[ -f "${migration_marker}" ]]; then
    echo "Official config import is enabled but already completed before. Skipping."
  else
    echo "Official config import requested."
    timestamp="$(date +%Y%m%d_%H%M%S)"
    backup_root="/share/music_assistant/migration_backups/${timestamp}"
    mkdir -p "${backup_root}"

    mapfile -t target_entries < <(find /data -mindepth 1 -maxdepth 1 2>/dev/null || true)
    if [[ "${#target_entries[@]}" -gt 0 ]] && ! is_true "${force_overwrite_on_import}"; then
      echo "WARNING: loader /data is not empty. Import skipped to avoid overwrite."
      echo "If you need to overwrite, set 'force_overwrite_on_import: true' once."
    else
      echo "Backing up current loader data -> ${backup_root}/loader_before_import"
      cp -a /data "${backup_root}/loader_before_import"

      source_dir=""
      detected_slug=""
      import_method=""

      if is_true "${auto_detect_official_slug}"; then
        echo "Trying auto-detect for official MA slug..."
        detected_slug="$(discover_slug_from_supervisor || true)"
        if [[ -n "${detected_slug}" ]]; then
          echo "Detected official slug via Supervisor API: ${detected_slug}"
          official_slug="${detected_slug}"
        fi
      fi
      if [[ -z "${official_slug}" ]] && is_true "${auto_detect_official_slug}"; then
        detected_slug="$(discover_slug_from_filesystem || true)"
        if [[ -n "${detected_slug}" ]]; then
          echo "Detected official slug via filesystem scan: ${detected_slug}"
          official_slug="${detected_slug}"
        fi
      fi
      if [[ -z "${official_slug}" ]]; then
        echo "Auto-detect did not return a slug. You may set 'official_slug' manually."
      fi

      if [[ -n "${official_slug}" ]]; then
        source_dir="$(find_source_dir_by_slug "${official_slug}" 2>/dev/null || true)"
      fi

      if [[ -n "${source_dir}" ]]; then
        echo "Found official add-on data directory: ${source_dir}"
        echo "Backing up visible official source data -> ${backup_root}/official_source"
        cp -a "${source_dir}" "${backup_root}/official_source"

        if is_true "${force_overwrite_on_import}"; then
          echo "Clearing existing loader /data before import..."
          find /data -mindepth 1 -maxdepth 1 ! -name 'options.json' -exec rm -rf {} +
        fi

        echo "Importing official MA config from '${source_dir}' to '/data'..."
        cp -a "${source_dir}/." /data/
        import_method="visible_dir_copy"
      else
        echo "Visible official addon data directory not found. Falling back to Supervisor backup migration..."
        log_import_probe
        if import_from_supervisor_backup "${official_slug}" "${backup_root}" "${force_overwrite_on_import}"; then
          import_method="supervisor_backup_api"
        fi
      fi

      if [[ -n "${import_method}" ]]; then
        official_backup_slug="$(head -n 1 "${backup_root}/supervisor_backup_slug.txt" 2>/dev/null || true)"
        write_migration_index "${backup_root}" "${official_slug}" "${import_method}" "${official_backup_slug}"
        {
          echo "timestamp=${timestamp}"
          echo "source_slug=${official_slug}"
          echo "backup_root=${backup_root}"
          echo "method=${import_method}"
          echo "official_backup_slug=${official_backup_slug}"
        } > "${migration_marker}"
        echo "Official config import completed successfully (method: ${import_method})."
      else
        echo "WARNING: Official config import failed. Continuing startup without migration."
      fi
    fi
  fi
fi

PROVIDERS_DIR=""
if ! PROVIDERS_DIR="$(
  python3 - <<'PY'
import importlib
import site
import sys
from pathlib import Path


def resolve_providers_dir() -> str:
    # Primary path: import the canonical package directly.
    try:
        pkg = importlib.import_module("music_assistant.providers")
        paths = list(getattr(pkg, "__path__", []))
        if paths:
            p = Path(paths[0])
            if p.is_dir():
                return str(p)
    except Exception:
        pass

    # Fallback: scan common site-packages locations.
    candidate_roots = []
    try:
        candidate_roots.extend(site.getsitepackages())
    except Exception:
        pass
    user_site = site.getusersitepackages()
    if user_site:
        candidate_roots.append(user_site)
    candidate_roots.extend(sys.path)

    seen = set()
    for root in candidate_roots:
        if not root or root in seen:
            continue
        seen.add(root)
        base = Path(root)
        if not base.is_dir():
            continue
        candidate = base / "music_assistant" / "providers"
        if candidate.is_dir():
            return str(candidate)

    raise RuntimeError(
        "Unable to locate Music Assistant providers directory. "
        "If MA internals changed, update loader path resolution."
    )


print(resolve_providers_dir())
PY
  )"; then
  if is_true "${strict_provider_injection}"; then
    echo "ERROR: failed to resolve Music Assistant providers directory and strict mode is enabled." >&2
    exit 1
  fi
  echo "WARNING: failed to resolve providers directory. Skipping custom provider injection."
fi

if [[ -n "${PROVIDERS_DIR}" && -d "${PROVIDERS_DIR}" ]]; then
  echo "Resolved internal providers directory: ${PROVIDERS_DIR}"
elif is_true "${strict_provider_injection}"; then
  echo "ERROR: providers directory not found: ${PROVIDERS_DIR}" >&2
  exit 1
else
  echo "WARNING: providers directory not found. Skipping custom provider injection."
  PROVIDERS_DIR=""
fi

if [[ -n "${PROVIDERS_DIR}" && -d "${CUSTOM_DIR}" ]]; then
  mapfile -t plugins < <(find "${CUSTOM_DIR}" -maxdepth 1 -mindepth 1 -type d | sort)
  if [[ "${#plugins[@]}" -eq 0 ]]; then
    echo "Custom providers directory exists but contains no plugins."
  else
    echo "Found ${#plugins[@]} custom plugin(s). Injecting..."
    for plugin in "${plugins[@]}"; do
      plugin_name="$(basename "${plugin}")"
      if [[ ! -f "${plugin}/__init__.py" || ! -f "${plugin}/manifest.json" ]]; then
        echo "Skipping ${plugin_name}: missing __init__.py or manifest.json"
        continue
      fi
      echo "Installing: ${plugin_name}"
      cp -rf "${plugin}" "${PROVIDERS_DIR}/"
    done
    echo "Injection complete."
  fi
elif [[ -z "${PROVIDERS_DIR}" ]]; then
  echo "Custom provider injection disabled for this boot due to unresolved providers path."
else
  echo "No custom providers directory found, skipping injection."
  echo "Create this directory to load plugins: ${CUSTOM_DIR}"
fi

echo "Starting Music Assistant..."
exec mass --config /data
