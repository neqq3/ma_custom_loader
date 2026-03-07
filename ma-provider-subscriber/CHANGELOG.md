# 更新日志

## 0.2.0

- 新增 Gitee 订阅源支持：`https://gitee.com/owner/repo`
- 新增 GitCode 订阅源支持：`https://gitcode.com/owner/repo`
- 保持 `owner/repo` 默认走 GitHub，兼容旧配置
- 增强网络代理机制：支持配置代理源功能 (`github_proxy`) 以加速国内对 GitHub 的请求，且该代理机制仅对 GitHub 生效，避免污染对 Gitee/GitCode 等国内源的请求
- 状态键增加平台前缀（如 `github:owner/repo`、`gitee:owner/repo`），避免同名仓库冲突

## 0.1.0

- 初始版本
- 支持订阅 GitHub 仓库并自动下载/更新 providers
- 支持 `owner/repo`、`owner/repo@tag`、GitHub URL 格式
- 支持周期检查与可选的已取消订阅目录清理
