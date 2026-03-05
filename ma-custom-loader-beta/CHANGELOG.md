# Changelog

## 2.7.10-beta.5

- Upstream MA: 2.7.10
- Enforce manual `official_slug` priority; auto-detect runs only when `official_slug` is empty.
- Switch migration path to Supervisor Backup API-only (remove filesystem scan/copy fallback).
- Ignore bootstrap files (`options.json`, `.official_import_done`) when checking whether `/data` is empty before import.
- Align beta Docker label version with add-on version `2.7.10-beta.5`.

## 2.7.10-beta.4

- Upstream MA: 2.7.10
- Add Supervisor Backup API migration fallback when direct add-on data path is not visible.
- Keep migration safety guards: one-time marker, backup-first flow, and optional overwrite.
- Continue startup even if migration fails, so plugin loading is unaffected.
- Write migration index README under `/share` and persist official backup slug in marker for rollback traceability.

## 2.7.10-beta.3

- Upstream MA: 2.7.10
- Use `all_addon_configs:ro` mapping for safe visibility test of add-on data directories under `/addon_configs`.
- Keep migration auto-detection and diagnostics; this release targets the "no visible base dir" migration failure.

## 2.7.10-beta.2

- Upstream MA: 2.7.10
- Fix Supervisor API auto-detection to avoid external curl dependency.
- Add import probe logs to show visible add-on data directories during migration.
- Improve migration diagnostics when official MA source directory is not found.

## 2.7.10-beta.1

- Upstream MA: 2.7.10
- Add optional one-time official MA config import flow.
- Add backup-first migration safety guards and migration marker.
- Add strict provider injection mode toggle.
- Add beta channel packaging and workflow separation.

## 2.0.0

- Initial release.
- Support for loading custom plugins from `/share/music_assistant/custom_providers`.
- Multi-arch support (`amd64`, `aarch64`).
