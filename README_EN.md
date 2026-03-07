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

**1. Short Syntax (Defaults to GitHub)**
Short format (like `owner/repo`) will only fetch from GitHub by default.
- `neqq3/ma_ncloud_music`
- `owner/repo@v1.2.3`

**2. Full URL (Recommended for users in China)**
Fast downloads from Gitee and GitCode. These sources connect directly and **strictly bypass the `github_proxy` setting**, preventing proxy pollution errors.
- `https://gitcode.com/neqq3/ma_ncloud_music`
- `https://gitee.com/andychao2020/music-assistant-providers`
- `https://github.com/owner/repo`

## Why Two Add-ons

- `custom-loader` handles local provider loading only.
- `provider-subscriber` handles network fetch/update only.
- This separation keeps MA runtime stable and follows a minimal-change strategy.

## Provider Repository Spec

See: [docs/provider_repo_spec.md](./docs/provider_repo_spec.md)
