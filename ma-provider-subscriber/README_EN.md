# Music Assistant Provider Subscriber

Subscribe provider repositories (GitHub/Gitee/GitCode) and auto-update them into:

`/share/music_assistant/custom_providers`

Works for both HA Add-on and Docker standalone with the same config schema.

## Config File Lookup Order

1. `SUBSCRIBER_CONFIG_PATH` (if set)
2. `/data/options.json` (HA Add-on)
3. `/config/options.json` (Docker)

## Source Examples

**1. Short Syntax (Defaults to GitHub)**
Short format (like `owner/repo`) will only fetch from GitHub by default.
- `neqq3/ma_ncloud_music`
- `owner/repo@v1.2.3`

**2. Full URL (Recommended for users in China)**
Fast downloads from Gitee and GitCode. These sources connect directly and **strictly bypass the `github_proxy` setting**, preventing proxy pollution errors.
- `https://gitcode.com/neqq3/ma_ncloud_music`
- `https://gitee.com/andychao2020/music-assistant-providers`
- `https://github.com/owner/repo`

## Notes

- No need to manually create `/share/music_assistant/custom_providers`.
- Built-in retry uses exponential backoff + jitter to avoid aggressive retry loops.
- See `DOCS.md` for full setup.