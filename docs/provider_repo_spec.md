# MA Provider 仓库结构规范（建议）

适用目标：希望被 `ma-provider-subscriber` 自动下载并更新的第三方 Provider 仓库。

## 1. 基础要求

每个 Provider 目录必须包含：

- `__init__.py`
- `manifest.json`

可选但推荐：

- `icon.svg`
- `README.md`

## 2. 推荐目录结构

单 Provider 仓库：

```text
repo-root/
  my_provider/
    __init__.py
    manifest.json
    icon.svg
```

多 Provider 仓库：

```text
repo-root/
  provider_a/
    __init__.py
    manifest.json
  provider_b/
    __init__.py
    manifest.json
```

## 3. 版本发布建议

- 推荐使用 GitHub Release + 语义化版本标签（例如 `v1.2.3`）。
- 如果没有 Release，订阅器会回退到默认分支。

## 4. 兼容性建议

- 不要把 provider 目录嵌套在过深路径里。
- `manifest.json` 与 `__init__.py` 放在同级目录。
- 仓库里可包含多个 provider，订阅器会自动识别并分别安装。
