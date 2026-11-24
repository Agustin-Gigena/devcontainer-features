#!/bin/bash
set -e

source dev-container-features-test-lib

check "gcr not installed" sh -c '! command -v gcr'
check "gwr not installed" sh -c '! command -v gwr'
check "pm_detect core still installed" sh -c 'command -v pm_detect'

reportResults
