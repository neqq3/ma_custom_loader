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
echo "🔧 Patching Ports to Avoid Conflicts..."
echo "======================================="

# 获取路径
MA_PATH=$(python3 -c "import music_assistant; print(music_assistant.__path__[0])")
SITE_PACKAGES=$(dirname "$MA_PATH")
echo "📂 Site Packages: $SITE_PACKAGES"

# 定义修补函数
patch_port() {
    local target_dir=$1
    local old_port=$2
    local new_port=$3
    local name=$4

    echo "🔍 Checking $name ($old_port -> $new_port)..."
    if grep -r "$old_port" "$target_dir" > /dev/null; then
        echo "   ⚠️  Found $old_port. Patching to $new_port..."
        grep -r "$old_port" "$target_dir" | cut -d: -f1 | sort | uniq | while read -r file; do
            echo "      -> Patching $file"
            sed -i "s/$old_port/$new_port/g" "$file"
        done
        echo "   ✅ $name patched."
    else
        echo "   ℹ️  No $old_port found for $name (or already patched)."
    fi
}

# 1. 修补 Ingress 端口 (8094 -> 8093) - 解决 Supervisor 冲突
patch_port "$MA_PATH" "8094" "8093" "Ingress Port"

# 2. 修补 Sendspin 端口 (8927 -> 8928) - 解决投屏组件冲突
# Sendspin 是 MA 的投屏/播放组件，默认绑定 8927，多实例运行时会冲突
if [ -d "$SITE_PACKAGES/aiosendspin" ]; then
    patch_port "$SITE_PACKAGES/aiosendspin" "8927" "8928" "Sendspin Port"
else
    echo "⚠️  aiosendspin directory not found at $SITE_PACKAGES/aiosendspin"
fi

# 3. 修补默认 Webserver 端口 (8095 -> 8099) - 解决默认启动冲突
# 确保首次启动时不会尝试绑定原版 MA 的 8095 端口
patch_port "$MA_PATH" "8095" "8099" "Default Web Port"

echo "======================================="
echo "🚀 Starting Music Assistant..."
echo "======================================="

# 3. 启动 MA 服务器
exec mass --config /data
