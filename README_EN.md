# Music Assistant Custom Loader Repository

This repository provides two Home Assistant add-ons:

1. `ma-custom-loader`
2. `ma-provider-subscriber`

## 1) Music Assistant (Custom Loader)

- **Slug**: `ma-custom-loader`
- **Purpose**: Inject custom providers from `/share/music_assistant/custom_providers` at startup.
- **Design goal**: Keep changes minimal against upstream MA for easier long-term maintenance.

## 2) Music Assistant Provider Subscriber

- **Slug**: `ma-provider-subscriber`
- **Purpose**: Subscribe third-party GitHub provider repositories and auto-download/update them into `/share/music_assistant/custom_providers`.
- **Use case**: Avoid manual download/upload every time.

### Source Examples

- `neqq3/ma_ncloud_music`
- `andychao2024/music-assistant-providers`
- `someuser/some-provider@v1.2.3`

## Why Two Add-ons

- `custom-loader` handles local provider loading only.
- `provider-subscriber` handles network fetch/update only.
- This separation keeps MA runtime stable and follows a minimal-change strategy.

## Provider Repository Spec

See: [docs/provider_repo_spec.md](./docs/provider_repo_spec.md)
