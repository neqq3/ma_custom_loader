# Music Assistant Provider Subscriber

Subscribe GitHub provider repositories and auto-update them into:

`/share/music_assistant/custom_providers`

Works for both HA Add-on and Docker standalone with the same config schema.

## Config File Lookup Order

1. `SUBSCRIBER_CONFIG_PATH` (if set)
2. `/data/options.json` (HA Add-on)
3. `/config/options.json` (Docker)

## Source Examples

- `neqq3/ma_ncloud_music`
- `andychao2024/music-assistant-providers`
- `owner/repo@v1.2.3`
- `https://github.com/owner/repo`

## Notes

- No need to manually create `/share/music_assistant/custom_providers`.
- Built-in retry uses exponential backoff + jitter to avoid aggressive retry loops.
- See `DOCS.md` for full setup.
