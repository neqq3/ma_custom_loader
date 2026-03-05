# Changelog

## 2.7.10-beta.4

- Add Supervisor Backup API migration fallback when direct addon data path is not visible.
- Keep migration safety guards: one-time marker, backup-first flow, and optional overwrite.
- Continue startup even if migration fails, so plugin loading is unaffected.
- Write migration index README under /share and persist official backup slug in marker for rollback traceability.

## 2.7.10-beta.3

- Use `all_addon_configs:ro` mapping for safe visibility test of add-on data directories under `/addon_configs`.
- Keep migration auto-detection and diagnostics; this release targets the "no visible base dir" migration failure.

## 2.7.10-beta.2

- Fix Supervisor API auto-detection to avoid external curl dependency.
- Add import probe logs to show visible add-on data directories during migration.
- Improve migration diagnostics when official MA source directory is not found.

## 2.7.10-beta.1

- Add optional one-time official MA config import flow.
- Add backup-first migration safety guards and migration marker.
- Add strict provider injection mode toggle.
- Add beta channel packaging and workflow separation.

## 2.0.0

- Initial release.
- Support for loading custom plugins from `/share/music_assistant/custom_providers`.
- Multi-arch support (`amd64`, `aarch64`).

