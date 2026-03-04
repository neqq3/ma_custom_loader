# Music Assistant (Custom Loader) (BETA)

这是 `ma-custom-loader` 的测试通道版本，用于先验证新功能，再决定是否合入稳定版。

## 核心能力

1. 基于官方 MA 镜像启动，尽量保持原版行为。
2. 启动时从 `/share/music_assistant/custom_providers` 注入自定义 provider。
3. 支持可选的一次性配置迁移（从原版 MA 导入到本 loader）。

## 配置项说明

- `log_level`：日志级别。
- `strict_provider_injection`：如果无法解析 MA 内部 providers 目录，是否直接启动失败。
  - `false`（默认）：跳过注入，MA 仍可启动。
  - `true`：解析失败即退出。
- `import_official_config`：是否执行一次性配置迁移。
- `auto_detect_official_slug`：当 `official_slug` 不可用时，自动探测原版 MA slug（Supervisor API + 文件系统扫描）。
- `official_slug`：原版 MA 的 slug（例如 `core_music_assistant` 或 `d6faf732_music_assistant`）。
- `force_overwrite_on_import`：迁移时允许覆盖当前 `/data`。

## 一次性迁移流程（建议）

1. 先关闭 `import_official_config`，正常启动一次确认可用。
2. 打开 `import_official_config: true`，保持 `force_overwrite_on_import: false`，先观察日志是否找到原版 MA。
3. 若提示目标 `/data` 非空且你确认要覆盖，再临时设置 `force_overwrite_on_import: true` 执行一次。
4. 迁移完成后会写入 `/data/.official_import_done`，后续不会重复迁移。
5. 建议把 `import_official_config` 重新设回 `false`。

## 安全与回滚

- 迁移前会备份两份数据到 `/share/music_assistant/migration_backups/<timestamp>/`：
  - `official_source`
  - `loader_before_import`
- 如需回滚，可停止 add-on 后还原上述备份目录内容。

## 已知限制

- 如果容器环境无法访问原版 MA 数据目录，自动迁移会跳过并提示 warning。

## License

Apache-2.0
