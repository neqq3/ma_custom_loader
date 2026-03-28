# Changelog

## 2.8.1

- 已同步至上游 Music Assistant 2.8.1
- Synced to upstream Music Assistant 2.8.1
- 上游发布说明: https://github.com/music-assistant/server/releases/tag/2.8.1
- Upstream release notes: https://github.com/music-assistant/server/releases/tag/2.8.1

## 2.8.0

- 已同步至上游 Music Assistant 2.8.0
- Synced to upstream Music Assistant 2.8.0
- 上游发布说明: https://github.com/music-assistant/server/releases/tag/2.8.0
- Upstream release notes: https://github.com/music-assistant/server/releases/tag/2.8.0

## 2.7.10.1

- Upstream MA: 2.7.10
- Merge beta-validated migration features into stable channel:
  - One-time official config import via Supervisor Backup API.
  - Manual `official_slug` priority; auto-detect only when empty.
  - Safe overwrite guard and pre-import local snapshot.
  - Strict/optional provider injection behavior toggle.
- Add stable translations for new configuration options.

## 2.7.10

- Upstream MA: 2.7.10
- Base image aligned with Music Assistant `2.7.10`.
- Keep custom provider loader behavior from `/share/music_assistant/custom_providers`.

## 2.0.0

- Upstream MA: N/A (initial custom-loader release)
- Initial release.
- Support for loading custom plugins from `/share/music_assistant/custom_providers`.
- Pre-loaded with NCloud Music plugin support.
- Multi-arch support (`amd64`, `aarch64`).
