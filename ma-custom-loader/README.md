# Music Assistant Custom Loader

支持加载第三方插件的 Music Assistant 加载项。

## 安装

1. 在 Home Assistant 中添加此仓库
2. 安装 "Music Assistant (Custom Loader)"
3. 启动加载项

## 与原版 MA 共存配置

如果你已经安装了原版 Music Assistant，需要修改端口以避免冲突：

### 方法一：先配置后启动（推荐）

1. **停止原版 MA**
2. **启动改版 MA** 并完成 setup
3. **修改端口**：
   - 在 MA UI 中：`Settings` → `Core modules` → `Webserver`
   - 修改 `Port` 为 `8099`（或其他未占用端口）
   - 点击 `SAVE`
4. **重启改版 MA**
5. **启动原版 MA**

现在两个版本可以同时运行：
- 原版 MA：`http://YOUR_HA_IP:8095`
- 改版 MA：`http://YOUR_HA_IP:8099`

### 方法二：仅使用改版（无需配置）

如果你不需要原版 MA，直接使用改版即可，保持默认端口 8095。

## 添加自定义插件

1. 在 Home Assistant 中创建目录：
   ```
   /share/music_assistant/custom_providers/
   ```

2. 将插件文件夹放入此目录：
   ```
   /share/music_assistant/custom_providers/
   └── your_plugin/
       ├── manifest.json
       ├── __init__.py
       └── ...
   ```

3. 重启 "Music Assistant (Custom Loader)" 加载项

4. 插件将自动加载，在 MA 设置中启用即可

## 常见问题

### 端口冲突错误

```
OSError: [Errno 98] address already in use
```

**解决方案**：按照上面的"与原版 MA 共存配置"步骤操作。

### 插件未加载

1. 检查插件目录路径是否正确
2. 查看加载项日志，确认插件已被检测到
3. 在 MA 设置中启用插件

## 支持

- 仓库：https://github.com/neqq3/ma_custom_loader
- Issues：https://github.com/neqq3/ma_custom_loader/issues
