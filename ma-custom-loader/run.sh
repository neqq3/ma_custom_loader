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
echo "🔧 Patching Ingress Port..."
echo "======================================="

# 3. 查找并替换硬编码的 Ingress 端口 (8094 -> 8093)
# 原版 MA 在 Add-on 模式下可能会强制绑定 8094，导致禁用 Ingress 后仍冲突
MA_PATH=$(python3 -c "import music_assistant; print(music_assistant.__path__[0])")
echo "📂 MA Location: $MA_PATH"

if grep -r "8094" "$MA_PATH" > /dev/null; then
    echo "⚠️  Found hardcoded port 8094. Patching to 8093..."
    grep -r "8094" "$MA_PATH" | cut -d: -f1 | sort | uniq | while read -r file; do
        echo "   -> Patching $file"
        sed -i 's/8094/8093/g' "$file"
    done
    echo "✅ Port patched."
else
    echo "ℹ️  No hardcoded port 8094 found (or already patched)."
fi

echo "======================================="
echo "🚀 Starting Music Assistant..."
echo "======================================="

# 3. 启动 MA 服务器
exec mass --config /data
