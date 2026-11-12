#!/usr/bin/env bash
# install.sh - copy configuration files to ~/.config/opencode/

set -e

# Determine home directory
HOME_DIR=\"$HOME\"

# Ensure target directory exists
mkdir -p \"$HOME_DIR/.config/opencode\"

# Copy example config to actual config file
cp opencode.example.json \"$HOME_DIR/.config/opencode/opencode.json\"

# Copy Firefox MCP config
cp mcp-firefox-config.json \"$HOME_DIR/.config/opencode/mcp-firefox-config.json\"

echo \"Configuration files installed to $HOME_DIR/.config/opencode/\"
echo \"Make sure to run 'npx -y @playwright/mcp@latest --config $HOME_DIR/.config/opencode/mcp-firefox-config.json' to start the server.\"