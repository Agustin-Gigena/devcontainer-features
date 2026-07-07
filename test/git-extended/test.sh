#!/bin/bash
set -e

# Import test library
source dev-container-features-test-lib

echo "=== Testing git-extended feature ==="

# Functionality tests
echo ""
echo "--- Testing pm_detect ---"
check "pm_detect script exists" test -f /usr/local/git-extended/pm_detect.sh
check "pm_detect is executable" test -x /usr/local/git-extended/pm_detect.sh
check "pm_detect helper available" test -f /home/vscode/bin/pm_detect

echo ""
echo "--- Testing gcr function ---"
check "gcr function source file exists" test -f /usr/local/git-extended/functions/gcr.sh
check "gcr function loaded in bashrc" grep -q "gcr.sh" /home/vscode/.bashrc

echo ""
echo "--- Testing gwr function ---"
check "gwr function source file exists" test -f /usr/local/git-extended/functions/gwr.sh
check "gwr function loaded in bashrc" grep -q "gwr.sh" /home/vscode/.bashrc

echo ""
echo "--- Testing post-checkout hook ---"
check "post-checkout hook exists" test -f /usr/local/git-extended/hooks/post-checkout
check "post-checkout hook is executable" test -x /usr/local/git-extended/hooks/post-checkout

echo ""
echo "--- Testing shell functions are available ---"
# Source the functions to test they work
check "can source git-extended functions" bash -c "source /usr/local/git-extended/functions/gcr.sh && type gcr"
check "can source gwr function" bash -c "source /usr/local/git-extended/functions/gwr.sh && type gwr"

echo ""
echo "=== All tests passed! ==="

reportResults