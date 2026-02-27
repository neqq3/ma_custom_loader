# Music Assistant Provider Subscriber 使用说明

本加载项/容器会把第三方 GitHub Provider 自动下载更新到：

`/share/music_assistant/custom_providers`

然后由 `ma-custom-loader` 注入到 Music Assistant。

## 统一配置模型

HAOS 和 Docker 使用同一套 JSON 字段。  
配置文件查找顺序：

1. `SUBSCRIBER_CONFIG_PATH`（若设置）
2. `/data/options.json`（HA Add-on）
3. `/config/options.json`（Docker）

## HAOS（Supervisor）使用步骤

1. 安装 `Music Assistant Provider Subscriber (订阅器)`。
2. 在配置页填写 `sources`，例如：
   - `neqq3/ma_ncloud_music`
   - `andychao2024/music-assistant-providers`
3. 保存并启动/重启订阅器。
4. 查看日志确认更新成功。
5. 重启 `ma-custom-loader` 让插件生效。

无需手动创建 `/share/music_assistant/custom_providers`。

## Docker 独立部署步骤

1. 复制以下文件：
   - `docker-compose.example.yml`
   - `options.example.json`，并重命名为 `./config/options.json`
2. 启动：

```bash
docker compose up -d
```

3. 将同一宿主机插件目录挂载到 MA 容器中，确保 MA 能读取 provider。

## 关键配置字段

- `update_strategy`: `latest_release` 或 `default_branch`
- `run_on_start`: 启动时执行一次
- `run_forever`: 是否持续循环
- `interval_minutes`: 更新检查间隔
- `retry_attempts`: 网络临时错误重试次数
- `retry_base_seconds`: 重试基准延迟（指数退避+抖动）
- `prune_removed`: 清理已取消订阅的托管插件

## sources 格式

- `owner/repo`
- `owner/repo@tag_or_branch`
- `https://github.com/owner/repo`
