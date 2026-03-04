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
  local addons_json=""
  if [[ -z "${SUPERVISOR_TOKEN:-}" ]]; then
    echo "Auto-detect: SUPERVISOR_TOKEN is missing, skip Supervisor API lookup." >&2
    return 1
  fi
  if ! command -v curl >/dev/null 2>&1; then
    echo "Auto-detect: curl is unavailable, skip Supervisor API lookup." >&2
    return 1
  fi
  addons_json="$(
  curl -fsSL \
    -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
    -H "Content-Type: application/json" \
    "http://supervisor/addons" 2>/dev/null
  )" || {
    echo "Auto-detect: Supervisor API request failed." >&2
    return 1
  }
  ADDONS_JSON="${addons_json}" python3 - <<'PY'
import json
import os
import re

try:
    payload = json.loads(os.environ.get("ADDONS_JSON", ""))
except Exception:
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

if is_true "${import_official_config}"; then
  if [[ -f "${migration_marker}" ]]; then
    echo "Official config import is enabled but already completed before. Skipping."
  else
    echo "Official config import requested."
    source_dir=""

    # Step 1: auto-detect first (recommended).
    if [[ -z "${source_dir}" ]] && is_true "${auto_detect_official_slug}"; then
      echo "Trying auto-detect for official MA slug..."
      detected_slug="$(discover_slug_from_supervisor || true)"
      if [[ -n "${detected_slug}" ]]; then
        source_dir="$(find_source_dir_by_slug "${detected_slug}" 2>/dev/null || true)"
        if [[ -n "${source_dir}" ]]; then
          echo "Detected official slug via Supervisor API: ${detected_slug}"
          official_slug="${detected_slug}"
        fi
      fi

      if [[ -z "${source_dir}" ]]; then
        detected_slug="$(discover_slug_from_filesystem || true)"
        if [[ -n "${detected_slug}" ]]; then
          source_dir="$(find_source_dir_by_slug "${detected_slug}" 2>/dev/null || true)"
          if [[ -n "${source_dir}" ]]; then
            echo "Detected official slug via filesystem scan: ${detected_slug}"
            official_slug="${detected_slug}"
          fi
        fi
      fi
    elif [[ -z "${source_dir}" ]]; then
      echo "Auto-detect is disabled."
    fi

    # Step 2: configured slug fallback.
    if [[ -z "${source_dir}" ]] && [[ -n "${official_slug}" ]]; then
      source_dir="$(find_source_dir_by_slug "${official_slug}" 2>/dev/null || true)"
      if [[ -n "${source_dir}" ]]; then
        echo "Found source by configured slug fallback: ${official_slug}"
      fi
    fi

    if [[ -z "${source_dir}" ]]; then
      echo "WARNING: official add-on data folder not found. Skipping import."
      echo "Checked auto-detect and configured slug fallback."
      echo "Tips: keep auto_detect_official_slug=true and leave official_slug empty, or set real slug manually."
    else
      mapfile -t target_entries < <(find /data -mindepth 1 -maxdepth 1 2>/dev/null || true)
      if [[ "${#target_entries[@]}" -gt 0 ]] && ! is_true "${force_overwrite_on_import}"; then
        echo "WARNING: loader /data is not empty. Import skipped to avoid overwrite."
        echo "If you need to overwrite, set 'force_overwrite_on_import: true' once."
      else
        timestamp="$(date +%Y%m%d_%H%M%S)"
        backup_root="/share/music_assistant/migration_backups/${timestamp}"
        mkdir -p "${backup_root}"

        echo "Backing up official source data -> ${backup_root}/official_source"
        cp -a "${source_dir}" "${backup_root}/official_source"

        echo "Backing up current loader data -> ${backup_root}/loader_before_import"
        cp -a /data "${backup_root}/loader_before_import"

        if is_true "${force_overwrite_on_import}"; then
          echo "Clearing existing loader /data before import..."
          find /data -mindepth 1 -maxdepth 1 -exec rm -rf {} +
        fi

        echo "Importing official MA config from '${source_dir}' to '/data'..."
        cp -a "${source_dir}/." /data/

        {
          echo "timestamp=${timestamp}"
          echo "source_slug=${official_slug}"
          echo "source_dir=${source_dir}"
          echo "backup_root=${backup_root}"
        } > "${migration_marker}"

        echo "Official config import completed successfully."
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
