#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_REPO="${UPSTREAM_REPO:-music-assistant/server}"
ADDON_CONFIG="${ADDON_CONFIG:-ma-custom-loader/config.yaml}"
DOCKERFILE="${DOCKERFILE:-ma-custom-loader/Dockerfile}"
CHANGELOG_FILE="${CHANGELOG_FILE:-ma-custom-loader/CHANGELOG.md}"
API_URL="https://api.github.com/repos/${UPSTREAM_REPO}/releases/latest"

auth_header=()
if [[ -n "${GH_TOKEN:-}" ]]; then
  auth_header=(-H "Authorization: Bearer ${GH_TOKEN}")
fi

release_json="$(
  curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    "${auth_header[@]}" \
    "${API_URL}"
)"

latest_version="$(
  printf '%s' "${release_json}" \
    | python3 -c 'import json,sys; print((json.load(sys.stdin).get("tag_name") or "").lstrip("v"))'
)"
if [[ -z "${latest_version}" ]]; then
  echo "ERROR: failed to detect latest upstream version from ${API_URL}" >&2
  exit 1
fi

current_version="$(sed -n 's/^version: "\(.*\)"/\1/p' "${ADDON_CONFIG}")"
if [[ -z "${current_version}" ]]; then
  echo "ERROR: failed to read current add-on version from ${ADDON_CONFIG}" >&2
  exit 1
fi

current_build_from="$(sed -n 's/^ARG BUILD_FROM=\(.*\)$/\1/p' "${DOCKERFILE}")"
current_upstream_version="$(sed -n 's/^upstream_version: "\(.*\)"/\1/p' "${ADDON_CONFIG}" || true)"
target_build_from="ghcr.io/music-assistant/server:${latest_version}"

echo "Current add-on version: ${current_version}"
echo "Current upstream_version: ${current_upstream_version:-<missing>}"
echo "Latest upstream version: ${latest_version}"
echo "Current Docker BUILD_FROM: ${current_build_from}"
echo "Target Docker BUILD_FROM: ${target_build_from}"

# Do not overwrite manual patch versions when upstream base did not change.
if [[ "${current_build_from}" == "${target_build_from}" ]]; then
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
      echo "changed=false"
      echo "version=${current_version}"
    } >> "${GITHUB_OUTPUT}"
  fi
  echo "No upstream base update needed. Keep current add-on version: ${current_version}"
  exit 0
fi

python3 - "${ADDON_CONFIG}" "${latest_version}" <<'PY'
from pathlib import Path
import re
import sys

config = Path(sys.argv[1])
latest = sys.argv[2]
text = config.read_text(encoding='utf-8')

# Always sync stable add-on version to latest upstream on upstream release.
text = re.sub(r'^version:\s*".*"$', f'version: "{latest}"', text, flags=re.M)

if re.search(r'^upstream_version:\s*".*"$', text, flags=re.M):
    text = re.sub(r'^upstream_version:\s*".*"$', f'upstream_version: "{latest}"', text, flags=re.M)
else:
    text = re.sub(r'^(version:\s*".*"\n)', r'\1' + f'upstream_version: "{latest}"\n', text, count=1, flags=re.M)

config.write_text(text, encoding='utf-8', newline='\n')
PY

release_json_file="$(mktemp)"
trap 'rm -f "${release_json_file}"' EXIT
printf '%s' "${release_json}" > "${release_json_file}"

python3 - "${CHANGELOG_FILE}" "${latest_version}" "${release_json_file}" <<'PY'
from pathlib import Path
import json
import re
import sys


def normalize_release_notes(body: str) -> list[str]:
    lines: list[str] = []
    for raw_line in body.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("#"):
            line = line.lstrip("#").strip()
        line = re.sub(r"^[-*+]\s+", "", line)
        line = re.sub(r"^\d+\.\s+", "", line)
        line = re.sub(r"\s+", " ", line).strip()
        if line:
            lines.append(line)
    deduped: list[str] = []
    seen: set[str] = set()
    for line in lines:
        key = line.casefold()
        if key in seen:
            continue
        seen.add(key)
        deduped.append(line)
    return deduped[:12]


changelog_path = Path(sys.argv[1])
latest = sys.argv[2]
release_json = json.loads(Path(sys.argv[3]).read_text(encoding="utf-8"))
release_name = (release_json.get("name") or "").strip()
release_url = (release_json.get("html_url") or "").strip()
release_body = release_json.get("body") or ""
release_notes = normalize_release_notes(release_body)

if changelog_path.exists():
    text = changelog_path.read_text(encoding="utf-8")
else:
    text = "# Changelog\n"

entry_lines = [
    f"## {latest}",
    "",
    f"- Upstream MA: {latest}",
    f"- Synced base image with Music Assistant `{latest}`.",
]

if release_name:
    entry_lines.append(f"- Upstream release: {release_name}")
if release_url:
    entry_lines.append(f"- Source release: {release_url}")

if release_notes:
    entry_lines.append("- Upstream release notes:")
    entry_lines.extend([f"  - {line}" for line in release_notes])
else:
    entry_lines.append("- Upstream release notes were empty in the upstream release payload.")

entry = "\n".join(entry_lines).rstrip() + "\n"

if not text.startswith("# Changelog"):
    text = "# Changelog\n\n" + text.lstrip()

pattern = re.compile(rf"(?ms)^## {re.escape(latest)}\n.*?(?=^## |\Z)")
if pattern.search(text):
    text = pattern.sub(entry + "\n", text, count=1)
else:
    parts = text.split("\n", 2)
    if len(parts) >= 2 and parts[0].strip() == "# Changelog":
        remainder = parts[2] if len(parts) == 3 else ""
        text = "# Changelog\n\n" + entry + ("\n" + remainder.lstrip("\n") if remainder else "")
    else:
        text = "# Changelog\n\n" + entry + "\n" + text.lstrip("\n")

text = re.sub(r"\n{3,}", "\n\n", text).rstrip() + "\n"
changelog_path.write_text(text, encoding="utf-8", newline="\n")
PY

sed -E -i "s#^ARG BUILD_FROM=.*#ARG BUILD_FROM=ghcr.io/music-assistant/server:${latest_version}#" "${DOCKERFILE}"
sed -E -i "s/(io\.hass\.version=\").*(\")/\1${latest_version}\2/" "${DOCKERFILE}"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "changed=true"
    echo "version=${latest_version}"
  } >> "${GITHUB_OUTPUT}"
fi

echo "Updated upstream base and stable add-on version to ${latest_version}."
