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

# 5. Configure MA server port
SERVER_PORT="${SERVER_PORT:-8095}"
CONFIG_FILE="/data/config.json"

echo "📝 Configuring MA server port: $SERVER_PORT"

# Create or update config.json with the correct port
if [ ! -f "$CONFIG_FILE" ]; then
    echo "   First run detected. Creating config file..."
    mkdir -p /data
    cat > "$CONFIG_FILE" << EOF
{
  "webserver": {
    "port": $SERVER_PORT
  }
}
EOF
else
    echo "   Existing config found. Updating port configuration..."
    # Use jq to update the port if config exists, or create minimal config if parsing fails
    if command -v jq >/dev/null 2>&1; then
        # Update using jq if available
        temp_file=$(mktemp)
        jq ".webserver.port = $SERVER_PORT" "$CONFIG_FILE" > "$temp_file" && mv "$temp_file" "$CONFIG_FILE"
    else
        # Fallback: use sed to update the port
        sed -i "s/\"port\": [0-9]*/\"port\": $SERVER_PORT/" "$CONFIG_FILE"
    fi
fi

echo "✅ Port configuration complete."

# 6. Start the server
exec mass --config /data
