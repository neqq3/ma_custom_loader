# Music Assistant (Customizable) Add-on

这是一个 **增强版** 的 Music Assistant Add-on。它拥有**加载任意第三方插件**的能力。

## 核心特性

1.  **官方原味**：基于官方镜像构建，不修改任何核心代码。
2.  **万能加载器**：支持从 `/share` 目录动态加载任何第三方插件。
3.  **零维护**：自动跟随官方版本更新。

##  如何安装插件

1.  确保你的 Home Assistant 安装了 Samba share 或 File Editor，能访问 `/share` 目录。
2.  创建目录：`/share/music_assistant/custom_providers`。
3.  将插件文件夹（例如 `ncloud_music`）放入上述目录中。
    *   结构应该是：`/share/music_assistant/custom_providers/ncloud_music/__init__.py`
4.  **重启** 本 Add-on。
5.  在日志中你会看到 `Injecting custom plugin(s)...` 的提示，说明加载成功。

##  开发者指南 (如何构建)

1.  Fork 本仓库。
2.  在 GitHub Actions 中启用 Workflow。
3.  手动触发 `Build and Publish Add-on`。
4.  在 Home Assistant 中添加你的仓库地址。

##  版权与协议

本项目基于 [Music Assistant](https://github.com/music-assistant/server) 构建。
Music Assistant 遵循 Apache-2.0 协议开源。
本项目同样遵循 **Apache-2.0** 协议。

**免责声明**：本项目仅提供插件加载机制。
