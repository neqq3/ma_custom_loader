# Music Assistant 自定义加载器仓库

本仓库提供一个 Home Assistant 的 Music Assistant 自定义 Add-on，核心能力是从 `/share` 目录注入自定义 provider。

[English Version](./README_EN.md)

## 当前维护的 Add-on

### Music Assistant (Custom Loader)
- **Slug**: `ma-custom-loader`
- **说明**: 标准版 MA 加载器，支持自定义 provider 注入
- **功能**:
  - 从 `/share/music_assistant/custom_providers` 加载自定义 provider
  - 支持 Ingress
  - 使用 MA 默认端口

`coexist` 版本已停止维护，并已从仓库入口中隐藏。

## 自动同步策略

仓库已配置定时自动同步机制：每天检查 `music-assistant/server` 最新 release，若发现新版本会自动更新 Add-on 元数据并发布镜像，减少手工改版本导致的问题。

## 安装

1. 在 Home Assistant Add-on Store 添加仓库地址：
   `https://github.com/neqq3/ma_custom_loader`
2. 安装 `Music Assistant (Custom Loader)`。

## 使用自定义插件

1. 创建目录 `/share/music_assistant/custom_providers`
2. 将插件目录放入该路径（每个插件目录内需包含 `__init__.py`、`manifest.json`）
3. 重启 Add-on
