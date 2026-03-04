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
official_slug="$(read_option str official_slug core_music_assistant)"
force_overwrite_on_import="$(read_option bool force_overwrite_on_import false)"
strict_provider_injection="$(read_option bool strict_provider_injection false)"
migration_marker="/data/.official_import_done"

if is_true "${import_official_config}"; then
  if [[ -f "${migration_marker}" ]]; then
    echo "Official config import is enabled but already completed before. Skipping."
  else
    echo "Official config import requested."
    source_dir=""
    for base in /addon_configs /data/addons/data; do
      candidate="${base}/${official_slug}"
      if [[ -d "${candidate}" ]]; then
        source_dir="${candidate}"
        break
      fi
    done

    if [[ -z "${source_dir}" ]]; then
      echo "WARNING: official add-on data folder not found for slug '${official_slug}'. Skipping import."
      echo "Set 'official_slug' to the exact folder name and retry."
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
