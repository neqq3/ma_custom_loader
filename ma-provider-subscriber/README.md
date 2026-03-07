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

**1. 默认简写（默认走 GitHub）**
简写格式（如 `owner/repo`）默认只从 GitHub 拉取。
- `neqq3/ma_ncloud_music`
- `owner/repo@v1.2.3`

**2. 完整链接（推荐国内用户，速度更快）**
支持使用 Gitee 或 GitCode 的完整仓库链接。使用国内源时代码将直连下载，**严格与 GitHub 隔离，不会受到 `github_proxy` 代理设置的干扰**，避免各种代理污染报错。
- `https://gitcode.com/neqq3/ma_ncloud_music`
- `https://gitee.com/andychao2020/music-assistant-providers`
- `https://github.com/owner/repo`

## 说明

- 无需手动创建 `/share/music_assistant/custom_providers`，会自动创建。
- 内置低频重试（指数退避 + 抖动），避免短时间高频请求。
- 详细说明见 `DOCS.md`。
