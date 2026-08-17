#!/bin/sh
set -e

echo "Activating feature 'dotnet-ef'"

# Environment variables from options (set by dev container CLI)
DOTNET_EF_VERSION=${VERSION:-latest}

# Install dotnet SDK if not present
if ! command -v dotnet > /dev/null 2>&1; then
    echo "dotnet SDK not found. Installing..."
    apt-get update && apt-get install -y wget
    wget -q https://dot.net/v1/dotnet-install.sh -O /tmp/dotnet-install.sh
    chmod +x /tmp/dotnet-install.sh

    /tmp/dotnet-install.sh --channel 8.0
    rm -f /tmp/dotnet-install.sh

    DOTNET_ROOT="$HOME/.dotnet"
    export PATH="$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools"

    PROFILE_FILE=""
    if [ -f "$HOME/.bashrc" ]; then
        PROFILE_FILE="$HOME/.bashrc"
    elif [ -f "$HOME/.profile" ]; then
        PROFILE_FILE="$HOME/.profile"
    fi
    if [ -n "$PROFILE_FILE" ]; then
        if ! grep -q '.dotnet' "$PROFILE_FILE" 2>/dev/null; then
            echo "export PATH=\"\$PATH:${DOTNET_ROOT}:${DOTNET_ROOT}/tools\"" >> "$PROFILE_FILE"
        fi
    fi
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
