# Music Assistant Provider Subscriber（订阅器）

[English](./README_EN.md)

订阅 GitHub Provider 仓库，并自动更新到：

`/share/music_assistant/custom_providers`

适用于 HA Add-on 和 Docker 独立部署，配置字段保持一致。

## 配置读取顺序

1. `SUBSCRIBER_CONFIG_PATH`（若设置）
2. `/data/options.json`（HA Add-on）
3. `/config/options.json`（Docker）

## 订阅源示例

- `neqq3/ma_ncloud_music`
- `andychao2024/music-assistant-providers`
- `owner/repo@v1.2.3`
- `https://github.com/owner/repo`

## 说明

- 无需手动创建 `/share/music_assistant/custom_providers`，会自动创建。
- 内置低频重试（指数退避 + 抖动），避免短时间高频请求。
- 详细说明见 `DOCS.md`。
