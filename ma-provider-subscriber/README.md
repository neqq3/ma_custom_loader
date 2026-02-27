# Music Assistant Provider Subscriber

用于订阅第三方 GitHub Provider 仓库，并自动下载更新到：

`/share/music_assistant/custom_providers`

再由 `ma-custom-loader` 注入到 Music Assistant。

## 快速使用

1. 在配置中填写 `sources`（每行一个）：
   - `neqq3/ma_ncloud_music`
   - `andychao2024/music-assistant-providers`
2. 保存并重启本加载项。
3. 查看日志确认已下载成功。
4. 重启 `ma-custom-loader` 让插件生效。

## Source 格式

- `owner/repo`
- `owner/repo@tag_or_branch`
- `https://github.com/owner/repo`

## 更新策略

- `latest_release`：优先使用最新 Release；无 Release 时回退默认分支
- `default_branch`：始终使用默认分支最新提交

## 说明

- 无需手动创建 `/share/music_assistant/custom_providers`，会自动创建。
- 如遇 GitHub API 限流，可在 `github_token` 填写 token。
- 详细说明见 `DOCS.md`。
