# Music Assistant Provider Subscriber

用于订阅第三方 GitHub Provider 仓库，并自动下载更新到：

`/share/music_assistant/custom_providers`

这样 `ma-custom-loader` 在启动时就能直接加载这些插件，不需要每次手动上传文件。

## Source 格式

在 `sources` 里每行一个仓库，支持：

- `owner/repo`（默认跟随发布策略）
- `owner/repo@tag_or_branch`（固定版本/分支）
- `https://github.com/owner/repo`

示例：

- `neqq3/ma_ncloud_music`
- `andychao2024/music-assistant-providers`
- `someuser/some-provider@v1.2.3`

## 更新策略

- `latest_release`：优先使用最新 Release；没有 Release 则回退默认分支
- `default_branch`：始终使用默认分支最新提交

## 推荐配置

- `interval_minutes: 360`（每 6 小时检查一次）
- `run_on_start: true`
- `run_forever: true`
- 如果仓库较多，建议配置 `github_token`，避免 GitHub 匿名 API 限流
