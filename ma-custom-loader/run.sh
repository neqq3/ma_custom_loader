#!/bin/bash
set -e

echo "=== Music Assistant Custom Loader ==="

# 1. Find Music Assistant providers directory safely
PROVIDERS_DIR=$(python3 -c "import music_assistant.providers as p; print(list(p.__path__)[0])")
echo "✅ Internal Providers Directory: $PROVIDERS_DIR"

# 2. Inject Custom Plugins (from User Share)
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

# 5. Configure MA server port if needed
SERVER_PORT="${SERVER_PORT:-8095}"
CONFIG_FILE="/data/config.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "📝 First run detected. Pre-configuring server port: $SERVER_PORT"
    mkdir -p /data
    cat > "$CONFIG_FILE" << EOF
{
  "webserver": {
    "port": $SERVER_PORT
  }
}
EOF
else
    echo "ℹ️  Existing config found. Server port can be changed in MA settings."
fi

# 6. Start the server
exec mass --config /data
