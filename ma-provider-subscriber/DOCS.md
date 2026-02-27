# Music Assistant Provider Subscriber 使用说明

这个加载项负责把第三方 GitHub Provider 自动下载/更新到：

`/share/music_assistant/custom_providers`

然后由 `ma-custom-loader` 在启动时自动注入加载。

## 快速开始

1. 安装并启动 `Music Assistant Provider Subscriber (订阅器)`。
2. 打开“配置”页，填写 `sources`：
   - `neqq3/ma_ncloud_music`
   - `andychao2024/music-assistant-providers`
3. 点击“保存”并重启订阅器。
4. 查看订阅器日志，确认出现 `更新完成` / `installed`。
5. 重启 `Music Assistant (Custom Loader)`，让新插件被注入。

## 配置项建议

- `update_strategy`: `latest_release`
- `run_on_start`: `true`
- `run_forever`: `true`
- `interval_minutes`: `360`

## sources 支持格式

- `owner/repo`
- `owner/repo@tag_or_branch`
- `https://github.com/owner/repo`

## 是否需要手动创建文件夹

不需要。加载项会自动创建 `/share/music_assistant/custom_providers`（如果不存在）。

## 常见问题

1. GitHub API 限流导致更新失败：
   - 在 `github_token` 填写个人 token（只读权限即可）。
2. 插件没生效：
   - 先看订阅器日志是否下载成功；
   - 再重启 `ma-custom-loader`。
