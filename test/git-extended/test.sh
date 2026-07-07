#!/bin/bash
set -e

# Import test library
source dev-container-features-test-lib

echo "=== Testing git-extended feature ==="

# Test pm_detect
echo "--- Testing pm_detect ---"
check "pm_detect script exists" test -f /usr/local/git-extended/pm_detect.sh
check "pm_detect is executable" test -x /usr/local/git-extended/pm_detect.sh

# Test gcr function
echo "--- Testing gcr function ---"
check "gcr function source file exists" test -f /usr/local/git-extended/functions/gcr.sh

# Test gwr function
echo "--- Testing gwr function ---"
check "gwr function source file exists" test -f /usr/local/git-extended/functions/gwr.sh

# Test post-checkout hook
echo "--- Testing post-checkout hook ---"
check "post-checkout hook exists" test -f /usr/local/git-extended/hooks/post-checkout

echo "=== All tests passed! ==="

reportResults