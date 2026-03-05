# Music Assistant (Customizable) Add-on

这是一个 **增强版** 的 Music Assistant Add-on。它拥有**加载任意第三方插件**的能力。

## 核心特性

1.  **官方原味**：基于官方镜像构建，不修改任何核心代码。
2. **万能加载器**：支持从 `/share/music_assistant/custom_providers` 动态加载第三方插件。
3. **零维护**：自动跟随官方版本更新（按仓库工作流同步）。
4. **可选无缝迁移**：可将原版 MA 配置一次性迁移到加载版（Supervisor API 方案）。

## 如何自动安装和更新插件（推荐）

推荐配合同仓库加载项 **Music Assistant Provider Subscriber** 使用：

- 仓库地址（就是本仓库）：`https://github.com/neqq3/ma_custom_loader`
- 作用：订阅 GitHub Provider 仓库，自动下载/更新到 `/share/music_assistant/custom_providers`。
- 优势：不需要手工复制插件文件，后续更新也可自动跟进。

## 如何手动安装插件

1. 确保 Home Assistant 已安装 Samba Share 或 File Editor，可访问 `/share`。
2. 创建目录：`/share/music_assistant/custom_providers`。
3. 将插件文件夹（例如 `ncloud_music`）放入上述目录。
   - 目录结构示例：`/share/music_assistant/custom_providers/ncloud_music/__init__.py`
4. 重启本 Add-on。
5. 在日志中看到 `Injecting custom plugin(s)...` 即表示加载成功。

## 配置项与迁移说明（可选）

- `log_level`：日志级别。
- `strict_provider_injection`：如果无法定位 MA 内部 providers 目录是否直接失败退出。
- `import_official_config`：**【核心选项】导入原版 MA 配置**。开启它，会在本次启动时自动从官方版 MA 完整迁移数据。
- `auto_detect_official_slug`：自动通过 Supervisor 识别官方版 MA 标识。通常保持开启即可。
- `official_slug`：手动指定原版 MA 的 slug。手填值优先级最高；仅在留空且启用自动识别时，才会走 Supervisor 自动识别（例如 `core_music_assistant`）。
- `force_overwrite_on_import`：**【危险选项】强制覆盖当前改版配置**。如果本改版已有数据，开启此项会强行用原版数据把它们覆盖掉！⚠️ **强烈建议：如果本改版已经进行过配置，在开启本选项前，先前往 HA 页面为主面板上的本加载项点击“创建备份”进行手动备份！这样可以方便回档。**如果是新安装的未配置的加载项，可以不用备份。

## 数据迁移与回滚机制说明

1. **原版数据安全保障**：迁移过程对官方原版 MA 的数据仅执行只读操作，不会对其进行任何修改或破坏。
2. **自动创建原版备份**：在执行迁移时，脚本会调用 Home Assistant Supervisor API 自动为当前的官方版 MA 创建一份完整系统备份。该备份存放在 HA 系统的 `/backup` 目录下以备不时之需（名称类似 `[MA Custom Loader] 原版MA配置(迁移前自动备份)...`）。
   - **回滚原版说明**：若需恢复官方原版 MA 的配置，请前往 Home Assistant 的“设置 -> 系统 -> 备份”页面，找到对应的备份项进行系统还原即可。
3. **改版配置本地快照**：若启用了 `force_overwrite_on_import`（强制覆盖当前改版配置），为防止误操作导致已有的改版数据丢失，脚本在执行覆盖前，会自动将当前的改版配置全量备份至共享目录：`\\<你的 HAOS IP>\share\music_assistant\migration_backups\<时间戳>\loader_before_import`。
   - **恢复改版说明**：如需恢复被覆盖的本改版数据，可通过 Samba 连入上述目录，将其中的文件覆盖回当前的加载项数据存储目录中。

> 注意：每次迁移时在 `/share/.../migration_backups/` 目录下生成的文件夹及 `README.txt` 迁移索引文件，仅作日志留档与本地排错使用。删除它们 **不会** 影响已保存在 HA 系统 `/backup` 目录中的官方系统备份包。

## 已知限制

- 迁移功能依赖 Supervisor API，因此仅支持运行在 Home Assistant OS / Supervised 模式下的环境。
- 如果原版 MA 加载项处于未安装或已卸载状态，Supervisor 无法为其创建备份，迁移会自动中止并提示 WARNING。

## 版权与协议

本项目基于 [Music Assistant](https://github.com/music-assistant/server) 构建。
Music Assistant 遵循 Apache-2.0 协议开源。
本项目同样遵循 **Apache-2.0** 协议。

**免责声明**：本项目仅提供插件加载机制与迁移辅助能力。
