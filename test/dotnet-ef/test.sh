#!/bin/bash
set -e

# Import test library
source dev-container-features-test-lib

echo "=== Testing dotnet-ef feature ==="

# Test dotnet-ef is installed
echo "--- Testing dotnet-ef installation ---"
check "dotnet-ef command exists" command -v dotnet-ef
check "dotnet-ef is executable" dotnet-ef --version

echo "=== All tests passed! ==="

reportResults
