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
# 使用 Python 读取 JSON（无需额外依赖）
SERVER_PORT=$(python3 -c "import json; print(json.load(open('/data/options.json', 'r')).get('server_port', 8095))" 2>/dev/null || echo "8095")
SETTINGS_FILE="/data/settings.json"

echo "   Target port: $SERVER_PORT"

# 确保数据目录存在
mkdir -p /data

if [ ! -f "$SETTINGS_FILE" ]; then
    echo "   First run detected. Creating settings with port $SERVER_PORT..."
    # 使用 Python 创建 JSON 配置（格式规范，易维护）
    python3 << EOF
import json
settings = {
    "core.webserver": {
        "instance_id": "webserver",
        "type": "core.webserver",
        "enabled": True,
        "name": "Webserver",
        "port": $SERVER_PORT,
        "bind_ip": "0.0.0.0",
        "base_url": ""
    }
}
with open("$SETTINGS_FILE", "w") as f:
    json.dump(settings, f, indent=2)
EOF
    echo "✅ Settings created with port $SERVER_PORT"
else
    echo "   Existing settings found. Updating webserver port..."
    # 使用 Python 更新端口配置（安全可靠）
    python3 << EOF
import json
try:
    with open("$SETTINGS_FILE", "r") as f:
        settings = json.load(f)
    
    # 确保 core.webserver 配置存在并更新端口
    if "core.webserver" not in settings:
        settings["core.webserver"] = {}
    settings["core.webserver"]["port"] = $SERVER_PORT
    
    with open("$SETTINGS_FILE", "w") as f:
        json.dump(settings, f, indent=2)
    print("✅ Port updated to $SERVER_PORT")
except Exception as e:
    print(f"⚠️  Failed to update port: {e}")
EOF
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
