#!/usr/bin/env bash
set -euo pipefail

echo "=== Music Assistant Custom Loader ==="

CUSTOM_DIR="${CUSTOM_PROVIDERS_DIR:-/share/music_assistant/custom_providers}"
echo "Checking custom providers in: ${CUSTOM_DIR}"

PROVIDERS_DIR="$(
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
)"

if [[ -z "${PROVIDERS_DIR}" || ! -d "${PROVIDERS_DIR}" ]]; then
  echo "ERROR: providers directory not found: ${PROVIDERS_DIR}" >&2
  exit 1
fi
echo "Resolved internal providers directory: ${PROVIDERS_DIR}"

if [[ -d "${CUSTOM_DIR}" ]]; then
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
else
  echo "No custom providers directory found, skipping injection."
  echo "Create this directory to load plugins: ${CUSTOM_DIR}"
fi

echo "Starting Music Assistant..."
exec mass --config /data
