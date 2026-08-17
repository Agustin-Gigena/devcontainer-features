#!/bin/bash
set -e

# Import test library
source dev-container-features-test-lib

echo "=== Testing git-extended feature ==="

# Test pm_detect
echo "--- Testing pm_detect ---"
check "pm_detect script exists" test -f /usr/local/git-extended/pm_detect.sh
check "pm_detect is executable" test -x /usr/local/git-extended/pm_detect.sh
check "pm_detect CLI wrapper exists" test -x /usr/local/bin/pm_detect

# Test gcr function
echo "--- Testing gcr function ---"
check "gcr function source file exists" test -f /usr/local/git-extended/functions/gcr.sh

# Test gwr function
echo "--- Testing gwr function ---"
check "gwr function source file exists" test -f /usr/local/git-extended/functions/gwr.sh

# Test post-checkout hook
echo "--- Testing post-checkout hook ---"
check "post-checkout hook exists" test -f /usr/local/git-extended/hooks/post-checkout
check "post-checkout hook is executable" test -x /usr/local/git-extended/hooks/post-checkout

# Test profile.d loading (not user shell rc injection)
echo "--- Testing profile.d loading ---"
check "profile.d script exists" test -f /etc/profile.d/git-extended.sh
check "profile.d script is executable" test -x /etc/profile.d/git-extended.sh

# Test system git config for hooks
echo "--- Testing git system config ---"
check "git core.hooksPath is configured system-wide" git config --system --get core.hooksPath

echo "=== All tests passed! ==="

reportResults
