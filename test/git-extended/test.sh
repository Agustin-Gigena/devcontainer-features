#!/bin/bash
set -e

source dev-container-features-test-lib

echo "=== Testing git-extended feature ==="

# Commands must work in a plain non-login shell (no profile.d involvement).
check "gcr command in non-login shell" sh -c 'command -v gcr'
check "gwr command in non-login shell" sh -c 'command -v gwr'
check "pm_detect command in non-login shell" sh -c 'command -v pm_detect'
check "shared library installed" test -f /usr/local/share/git-extended/pm_detect.sh
check "no profile.d hook left" test ! -e /etc/profile.d/git-extended.sh
check "old functions dir removed" test ! -e /usr/local/git-extended
check "gcr without args fails" sh -c '! gcr 2>/dev/null'
check "gwr without args fails" sh -c '! gwr 2>/dev/null'
check "pm_detect outside a repo exits 0" sh -c 'cd /tmp && pm_detect'

# Runtime behavior: fake manager binaries prove which commands run (no network).
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
make_fake() {
    printf '#!/bin/sh\necho RAN-%s >> "%s"\n' "$1" "$TMP/log" > "$TMP/bin/$1"
    chmod +x "$TMP/bin/$1"
}
for m in npm pnpm yarn bun dotnet composer cargo; do
    make_fake "$m"
done
# bundle always fails, to test that one broken manager does not block others.
printf '#!/bin/sh\necho BUNDLE-TRIED >> "%s"\nexit 1\n' "$TMP/log" > "$TMP/bin/bundle"
chmod +x "$TMP/bin/bundle"
export FAKE_PATH="$TMP/bin:$PATH"

# Repo 1: pnpm monorepo with a .NET project — pnpm (not npm) + dotnet both run.
mkdir -p "$TMP/repo1"
git -C "$TMP/repo1" init -q
touch "$TMP/repo1/package.json" "$TMP/repo1/pnpm-lock.yaml" "$TMP/repo1/app.csproj"
check "lockfile selects pnpm over npm" env PATH="$FAKE_PATH" sh -c "cd '$TMP/repo1' && pm_detect && grep -q RAN-pnpm '$TMP/log'"
check "npm not run when pnpm lockfile present" env PATH="$FAKE_PATH" sh -c "! grep -q RAN-npm '$TMP/log'"
check "dotnet updates alongside the JS manager" grep -q RAN-dotnet "$TMP/log"

# Repo 2: package.json only inside node_modules must not trigger anything.
mkdir -p "$TMP/repo2/node_modules/somepkg"
git -C "$TMP/repo2" init -q
touch "$TMP/repo2/node_modules/somepkg/package.json"
check "nested vendored package.json ignored" env PATH="$FAKE_PATH" sh -c "cd '$TMP/repo2' && pm_detect && ! grep -q RAN-npm '$TMP/log'"

# Repo 3: failing manager does not block the others (bundle exits 1, npm runs).
mkdir -p "$TMP/repo3"
git -C "$TMP/repo3" init -q
touch "$TMP/repo3/package.json" "$TMP/repo3/Gemfile"
check "one failing manager does not block others" env PATH="$FAKE_PATH" sh -c "cd '$TMP/repo3' && pm_detect; grep -q RAN-npm '$TMP/log'"
check "failing manager reported" grep -q BUNDLE-TRIED "$TMP/log"

# Repo 4: manager declared by marker but not installed is skipped with a warning.
mkdir -p "$TMP/repo4"
git -C "$TMP/repo4" init -q
touch "$TMP/repo4/composer.json"
check "missing manager skipped with warning" env PATH="/usr/local/bin:/usr/bin:/bin" sh -c "cd '$TMP/repo4' && pm_detect 2>'$TMP/warn' && grep -q 'composer not installed' '$TMP/warn'"

echo "=== All tests passed! ==="

reportResults
