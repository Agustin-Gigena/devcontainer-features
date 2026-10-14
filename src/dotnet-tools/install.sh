#!/usr/bin/env bash
set -e

# DevContainers injects options in uppercase
TOOLS_LIST=${TOOLS:-""}
TARGET_DIR="/usr/local/share/dotnet-tools"

if [ -z "$TOOLS_LIST" ]; then
    echo "No .NET tools specified to install."
    exit 0
fi

# Verify dotnet SDK is installed
if ! command -v dotnet &> /dev/null; then
    echo "Error: 'dotnet' CLI not found. Ensure the .NET SDK is installed before running this feature."
    exit 1
fi

echo "Creating target directory: $TARGET_DIR"
mkdir -p "$TARGET_DIR"
chmod 755 "$TARGET_DIR"

# Convert comma-separated list into an array
IFS=',' read -r -a TOOLS_ARRAY <<< "$TOOLS_LIST"

for tool in "${TOOLS_ARRAY[@]}"; do
    # Trim whitespace
    tool=$(echo "$tool" | xargs)
    
    if [ -n "$tool" ]; then
        echo "Installing .NET tool: $tool"
        # Install to the shared global path. If a single tool fails to install, warn and continue.
        if ! dotnet tool install "$tool" --tool-path "$TARGET_DIR"; then
            echo "Warning: Failed to install '$tool'. Continuing with remaining tools." >&2
            continue
        fi
    fi
done

# Ensure installed binaries are executable by all users
chmod -R 755 "$TARGET_DIR"

echo "Installation of .NET tools completed."
