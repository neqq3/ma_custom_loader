#!/bin/bash
set -e

echo "=== Music Assistant Custom Loader ==="

# 1. 查找 Music Assistant providers 目录
PROVIDERS_DIR=$(python3 -c "import music_assistant.providers as p; print(list(p.__path__)[0])")
echo "✅ Internal Providers Directory: $PROVIDERS_DIR"

# 2. 注入自定义插件 (从用户共享目录)
CUSTOM_DIR="/share/music_assistant/custom_providers"
echo "📂 Checking for custom plugins in: $CUSTOM_DIR"

if [ -d "$CUSTOM_DIR" ]; then
    count=$(find "$CUSTOM_DIR" -maxdepth 1 -mindepth 1 -type d | wc -l)
    
    if [ "$count" -gt 0 ]; then
        echo "🔄 Found $count custom plugin(s). Injecting..."
        
        for plugin in "$CUSTOM_DIR"/*; do
            if [ -d "$plugin" ]; then
                plugin_name=$(basename "$plugin")
                echo "   -> Installing: $plugin_name"
                cp -rf "$plugin" "$PROVIDERS_DIR/"
            fi
        done
        
        echo "✅ Injection complete."
    else
        echo "⚠️  Custom folder exists but is empty."
    fi
else
    echo "ℹ️  No custom providers folder found. Skipping injection."
    echo "💡 To add plugins, create: /share/music_assistant/custom_providers"
fi

echo "======================================="
echo "🔧 Configuring MA webserver port..."
echo "======================================="

# 3. 从 add-on 配置读取用户自定义端口（默认 8095）
SERVER_PORT=$(jq -r '.server_port // 8095' /data/options.json 2>/dev/null || echo "8095")
SETTINGS_FILE="/data/settings.json"

echo "   Target port: $SERVER_PORT"

# 确保数据目录存在
mkdir -p /data

if [ ! -f "$SETTINGS_FILE" ]; then
    echo "   First run detected. Creating settings with port $SERVER_PORT..."
    # 创建最小化配置，设置用户指定的端口
    cat > "$SETTINGS_FILE" <<EOF
{
  "core.webserver": {
    "instance_id": "webserver",
    "type": "core.webserver",
    "enabled": true,
    "name": "Webserver",
    "port": $SERVER_PORT,
    "bind_ip": "0.0.0.0",
    "base_url": ""
  }
}
EOF
    echo "✅ Settings created with port $SERVER_PORT"
else
    echo "   Existing settings found. Updating webserver port..."
    # 使用 jq 更新 webserver 端口
    if command -v jq >/dev/null 2>&1; then
        temp_file=$(mktemp)
        # 确保 core.webserver 配置存在并设置端口
        jq '. + {"core.webserver": ((.["core.webserver"] // {}) + {"port": '$SERVER_PORT'})}' "$SETTINGS_FILE" > "$temp_file" && mv "$temp_file" "$SETTINGS_FILE"
        echo "✅ Port updated to $SERVER_PORT"
    else
        echo "⚠️  jq not found. Port configuration may not work correctly."
    fi
fi

echo "======================================="
echo "🚀 Starting Music Assistant..."
echo "======================================="
echo "📌 MA Custom Loader will use port $SERVER_PORT"
if [ "$SERVER_PORT" != "8095" ]; then
    echo "   ℹ️  Custom port configured to avoid conflict with original MA"
fi
echo "======================================="

# 4. 启动 MA 服务器
exec mass --config /data
