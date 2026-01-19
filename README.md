# Music Assistant 自定义加载器仓库

本仓库提供 Music Assistant 的自定义 Home Assistant 加载项，核心特性是支持从 `/share` 目录加载第三方或自定义插件。

[English Version](./README_EN.md)

## 可用加载项

本仓库包含两个版本的加载项，请根据您的需求选择：

### 1. Music Assistant (Custom Loader)
**标准版** - 推荐单实例用户使用。

- **定位**：基于官方稳定版的纯净加载器。
- **核心功能**：支持加载自定义插件。
- **端口配置**：使用默认端口（Web: 8095, Stream: 8097）。
- **侧边栏**：支持 Ingress 侧边栏访问。
- **适用场景**：如果您不需要同时运行官方原版 Add-on，请选择此版本。

### 2. Music Assistant (Coexistence)
**共存版** - 推荐开发者或测试用户使用。

- **定位**：专为解决端口冲突设计的特殊版本。
- **核心功能**：
    - **共存**：自动规避与官方 Add-on 的端口冲突。
    - **自定义端口**：默认 Web 端口调整为 **8099**，流媒体端口调整为 **8098**。
    - **侧边栏支持**：Ingress 端口调整为 **8093**，支持独立侧边栏。
    - **插件支持**：同样支持加载自定义插件。
- **适用场景**：如果您希望在保留官方原版 Add-on 的同时，运行第二个实例来测试插件或新功能，请选择此版本。

## 安装说明

1. 复制本仓库地址：
   `https://github.com/neqq3/ma_custom_loader`
2. 在 Home Assistant 的 **Add-on Store (加载项商店)** 中，点击右上角菜单 -> **Repositories (仓库)**。
3. 粘贴地址并添加。
4. 刷新商店，即可看到上述两个加载项。

## 使用指南：加载自定义插件

无论使用哪个版本，加载自定义插件的方法一致：

1. 确保您的 Home Assistant 安装了 Samba share 或有文件访问权限。
2. 在 `/share` 目录下创建路径：`/share/music_assistant/custom_providers`。
3. 将您的插件文件夹（包含 `__init__.py` 和 `manifest.json`）放入该目录。
   - 结构示例：`/share/music_assistant/custom_providers/my_custom_plugin/`
4. 重启 Add-on。
5. 启动日志中将显示 `Injecting...` 提示，表明插件已成功注入。

## 免责声明

本项目非 Music Assistant 官方项目。使用自定义插件可能导致系统不稳定，请自行承担风险。
