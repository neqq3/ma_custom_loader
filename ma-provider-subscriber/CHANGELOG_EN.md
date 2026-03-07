# Changelog

## 0.2.0

- Added Gitee source support: `https://gitee.com/owner/repo`
- Added GitCode source support: `https://gitcode.com/owner/repo`
- Kept `owner/repo` defaulting to GitHub for backward compatibility
- Enhanced network proxy mechanism: Added support for configuring a proxy source (`github_proxy`) to accelerate requests to GitHub, and this mechanism only applies to GitHub to avoid side effects on other providers like Gitee/GitCode
- State keys now include provider prefix (for example `github:owner/repo`, `gitee:owner/repo`) to avoid collisions

## 0.1.0

- Initial release
- Subscribe GitHub repositories and auto-download/update providers
- Supports `owner/repo`, `owner/repo@tag`, and GitHub URL formats
- Supports periodic checks and optional prune of removed managed providers
