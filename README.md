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

### 订阅源示例 (Source)

**1. 默认简写（默认走 GitHub）**
简写格式（如 `owner/repo`）默认只从 GitHub 拉取。
- `neqq3/ma_ncloud_music`
- `owner/repo@v1.2.3`

**2. 完整链接（推荐国内用户，速度更快）**
支持使用 Gitee 或 GitCode 的完整仓库链接。使用国内源时代码将直连下载，**严格与 GitHub 隔离，不会受到 `github_proxy` 代理设置的干扰**，避免各种代理污染报错。
- `https://gitcode.com/neqq3/ma_ncloud_music`
- `https://gitee.com/andychao2020/music-assistant-providers`
- `https://github.com/owner/repo`

## 插件仓库规范

见文档：[docs/provider_repo_spec.md](./docs/provider_repo_spec.md)
