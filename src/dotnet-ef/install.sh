#!/bin/sh
set -e

echo "Activating feature 'dotnet-ef'"

# Environment variables from options (set by dev container CLI)
DOTNET_EF_VERSION=${VERSION:-latest}

# Verify dotnet SDK is available
if ! command -v dotnet > /dev/null 2>&1; then
    echo "Error: dotnet SDK not found. Install it first with the dotnet feature."
    exit 1
fi

# Install dotnet-ef global tool
if [ "$DOTNET_EF_VERSION" = "latest" ]; then
    echo "Installing dotnet-ef (latest)..."
    dotnet tool install --global dotnet-ef
else
    echo "Installing dotnet-ef version ${DOTNET_EF_VERSION}..."
    dotnet tool install --global dotnet-ef --version "$DOTNET_EF_VERSION"
fi

# Ensure ~/.dotnet/tools is in PATH for all shells
TOOLS_DIR="$HOME/.dotnet/tools"
PROFILE_FILE=""
if [ -f "$HOME/.bashrc" ]; then
    PROFILE_FILE="$HOME/.bashrc"
elif [ -f "$HOME/.zshrc" ]; then
    PROFILE_FILE="$HOME/.zshrc"
elif [ -f "$HOME/.profile" ]; then
    PROFILE_FILE="$HOME/.profile"
fi

if [ -n "$PROFILE_FILE" ]; then
    if ! grep -q '.dotnet/tools' "$PROFILE_FILE" 2>/dev/null; then
        echo "export PATH=\"\$PATH:${TOOLS_DIR}\"" >> "$PROFILE_FILE"
        echo "Added ~/.dotnet/tools to PATH in ${PROFILE_FILE}"
    fi
fi

# Also export for current session
export PATH="$PATH:$TOOLS_DIR"

# Verify installation
if command -v dotnet-ef > /dev/null 2>&1; then
    INSTALLED_VERSION=$(dotnet-ef --version 2>/dev/null || echo "unknown")
    echo "dotnet-ef installed successfully! Version: ${INSTALLED_VERSION}"
else
    echo "dotnet-ef installed to ${TOOLS_DIR}. You may need to restart your shell."
fi
