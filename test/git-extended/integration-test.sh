#!/bin/bash
set -e

# Import test library
source dev-container-features-test-lib

echo "=== Integration Tests for git-extended ==="

echo ""
echo "--- Testing gcr function ---"
# Load the function
source /usr/local/git-extended/functions/gcr.sh

# Test help output
check "gcr shows help without arguments" bash -c "source /usr/local/git-extended/functions/gcr.sh && gcr 2>&1 | grep -q 'Usage'"

echo ""
echo "--- Testing gwr function ---"
# Load the function
source /usr/local/git-extended/functions/gwr.sh

# Test help output
check "gwr shows help without arguments" bash -c "source /usr/local/git-extended/functions/gwr.sh && gwr 2>&1 | grep -q 'Usage'"

echo ""
echo "--- Testing pm_detect functionality ---"
# Create a test git repository with package.json
TEST_DIR="/tmp/test-npm-repo"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"
git init --quiet
echo '{"name":"test","dependencies":{"lodash":"^4.0.0"}}' > package.json

# Source pm_detect and run
source /usr/local/git-extended/pm_detect.sh
check "pm_detect detects npm" bash -c "source /usr/local/git-extended/pm_detect.sh && run_pm_check 2>&1 | grep -q 'npm'"

cd - > /dev/null
rm -rf "$TEST_DIR"

echo ""
echo "=== Integration tests complete ==="

reportResults