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
echo "🚀 Starting Music Assistant..."
echo "======================================="

# 3. 启动 MA 服务器
exec mass --config /data
