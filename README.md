# Music Assistant 自定义加载仓库

本仓库面向 Home Assistant，提供两个相关 Add-on：

1. `ma-custom-loader`
2. `ma-provider-subscriber`

[English Version](./README_EN.md)

## 1) Music Assistant (Custom Loader)

- **Slug**: `ma-custom-loader`
- **作用**: 启动 MA 时，从 `/share/music_assistant/custom_providers` 注入自定义 provider
- **定位**: 尽量少改 MA 原版行为，保持长期可维护

## 2) Music Assistant Provider Subscriber

- **Slug**: `ma-provider-subscriber`
- **作用**: 订阅第三方 GitHub provider 仓库，自动下载/更新到
  `/share/music_assistant/custom_providers`
- **典型用法**: 给常用插件仓库做自动更新，避免每次手工下载上传

### Source 示例

- `neqq3/ma_ncloud_music`
- `andychao2024/music-assistant-providers`
- `someuser/some-provider@v1.2.3`

## 插件仓库规范

见文档：[docs/provider_repo_spec.md](./docs/provider_repo_spec.md)
