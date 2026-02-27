#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_REPO="${UPSTREAM_REPO:-music-assistant/server}"
ADDON_CONFIG="${ADDON_CONFIG:-ma-custom-loader/config.yaml}"
DOCKERFILE="${DOCKERFILE:-ma-custom-loader/Dockerfile}"
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
current_label_version="$(sed -n 's/.*io\.hass\.version=\"\(.*\)\"/\1/p' "${DOCKERFILE}")"
target_build_from="ghcr.io/music-assistant/server:${latest_version}"

echo "Current add-on version: ${current_version}"
echo "Latest upstream version: ${latest_version}"
echo "Current Docker BUILD_FROM: ${current_build_from}"
echo "Target Docker BUILD_FROM: ${target_build_from}"

if [[ \
  "${current_version}" == "${latest_version}" \
  && "${current_build_from}" == "${target_build_from}" \
  && "${current_label_version}" == "${latest_version}" \
]]; then
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
      echo "changed=false"
      echo "version=${current_version}"
    } >> "${GITHUB_OUTPUT}"
  fi
  echo "No version update needed."
  exit 0
fi

sed -E -i "s/^version: \".*\"$/version: \"${latest_version}\"/" "${ADDON_CONFIG}"
sed -E -i "s#^ARG BUILD_FROM=.*#ARG BUILD_FROM=ghcr.io/music-assistant/server:${latest_version}#" "${DOCKERFILE}"
sed -E -i "s/(io\.hass\.version=\").*(\")/\1${latest_version}\2/" "${DOCKERFILE}"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "changed=true"
    echo "version=${latest_version}"
  } >> "${GITHUB_OUTPUT}"
fi

echo "Updated add-on version to ${latest_version}."
