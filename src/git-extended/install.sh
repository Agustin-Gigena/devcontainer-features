#!/bin/sh
set -e

echo "Activating feature 'git-extended'"

INSTALL_GCR="${INSTALLGCRFUNCTION:-true}"
INSTALL_GWR="${INSTALLGWRFUNCTION:-true}"

LIB_DIR="/usr/local/share/git-extended"
BIN_DIR="/usr/local/bin"

mkdir -p "$LIB_DIR"

# Remove leftovers from pre-1.1.0 versions, which shipped shell functions via
# /etc/profile.d and files under /usr/local/git-extended; cached image layers
# may still contain them.
rm -f /etc/profile.d/git-extended.sh
rm -rf /usr/local/git-extended

cat > "$LIB_DIR/pm_detect.sh" << 'PM_DETECT_LIB_EOF'
# pm_detect.sh - shared library for the git-extended feature.
# Detects every package manager used by the current git repository and
# updates its dependencies. Sourced by gcr, gwr and the pm_detect command.

run_pm_check() {
    REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
        echo "[pm_detect] not inside a git repository, skipping" >&2
        return 0
    }

    # Single scan pass; pruned dirs keep vendored/nested copies from
    # triggering installs (e.g. node_modules/*/package.json).
    FOUND=$(cd "$REPO_ROOT" && find . -maxdepth 6 \
        \( -name .git -o -name node_modules -o -name vendor -o -name target -o -name bin -o -name obj \) -prune -o -type f \
        \( -name package.json -o -name pnpm-lock.yaml -o -name yarn.lock -o -name bun.lock -o -name bun.lockb \
           -o -name '*.csproj' -o -name '*.fsproj' -o -name '*.sln' \
           -o -name composer.json -o -name Gemfile -o -name Cargo.toml \
        \) -print 2>/dev/null) || true

    QUEUE=""
    if echo "$FOUND" | grep -q 'package\.json$'; then
        if echo "$FOUND" | grep -q 'pnpm-lock\.yaml$'; then
            QUEUE="
pnpm install"
        elif echo "$FOUND" | grep -q 'yarn\.lock$'; then
            QUEUE="
yarn install"
        elif echo "$FOUND" | grep -qE 'bun\.lockb?$'; then
            QUEUE="
bun install"
        else
            QUEUE="
npm install"
        fi
    fi
    if echo "$FOUND" | grep -qE '\.(cs|fs)proj$|\.sln$'; then
        QUEUE="$QUEUE
dotnet restore"
    fi
    if echo "$FOUND" | grep -q 'composer\.json$'; then
        QUEUE="$QUEUE
composer install"
    fi
    if echo "$FOUND" | grep -q 'Gemfile$'; then
        QUEUE="$QUEUE
bundle install"
    fi
    if echo "$FOUND" | grep -q 'Cargo\.toml$'; then
        QUEUE="$QUEUE
cargo fetch"
    fi

    if [ -z "$QUEUE" ]; then
        echo "[pm_detect] no known package manager files found"
        return 0
    fi

    FAILED=0
    while IFS= read -r CMD; do
        if [ -z "$CMD" ]; then continue; fi
        MGR=${CMD%% *}
        if ! command -v "$MGR" >/dev/null 2>&1; then
            echo "[pm_detect][WARN] $MGR not installed, skipping: $CMD" >&2
            continue
        fi
        echo "[pm_detect] $CMD"
        if ! (cd "$REPO_ROOT" && eval "$CMD" < /dev/null); then
            echo "[pm_detect][ERROR] failed: $CMD" >&2
            FAILED=1
        fi
    done <<EOF
$QUEUE
EOF

    if [ "$FAILED" -eq 1 ]; then
        echo "[pm_detect] dependency update finished with errors" >&2
    else
        echo "[pm_detect] dependency update completed"
    fi
    return "$FAILED"
}
PM_DETECT_LIB_EOF

cat > "$BIN_DIR/pm_detect" << 'PM_DETECT_CLI_EOF'
#!/bin/sh
# pm_detect - update dependencies for every package manager found in the repo.
. /usr/local/share/git-extended/pm_detect.sh
run_pm_check
PM_DETECT_CLI_EOF
chmod 755 "$BIN_DIR/pm_detect"

if [ "$INSTALL_GCR" = "true" ]; then
cat > "$BIN_DIR/gcr" << 'GCR_EOF'
#!/bin/sh
# gcr - checkout a remote base branch into a local branch.
# Usage: gcr <remote-base-branch> [new-branch-suffix]
set -e

if [ -z "${1:-}" ]; then
    echo "Usage: gcr <remote-base-branch> [new-branch-suffix]" >&2
    exit 1
fi

BRANCH_NAME="${1}${2:+_${2}}"
git fetch --tags --prune-tags origin

# -B forcibly moves an existing local branch; warn when that discards
# commits the remote does not have (recoverable via reflog).
UNPUBLISHED=$(git rev-list --count "origin/$1..$BRANCH_NAME" 2>/dev/null || true)
if [ -n "$UNPUBLISHED" ] && [ "$UNPUBLISHED" -gt 0 ]; then
    echo "[gcr] WARNING: '$BRANCH_NAME' has $UNPUBLISHED commit(s) not on origin/$1" >&2
    echo "[gcr] resetting discards them from the branch; recover with: git reflog" >&2
fi
git checkout -t "origin/$1" -B "$BRANCH_NAME"

# Dependency update is secondary to the checkout: report failures without
# failing the git operation.
. /usr/local/share/git-extended/pm_detect.sh
run_pm_check || true
GCR_EOF
chmod 755 "$BIN_DIR/gcr"
else
# Converge on re-install: a cached layer may still hold the command from a
# previous build where this option was true.
rm -f "$BIN_DIR/gcr"
fi

if [ "$INSTALL_GWR" = "true" ]; then
cat > "$BIN_DIR/gwr" << 'GWR_EOF'
#!/bin/sh
# gwr - create a git worktree tracking a remote base branch.
# Usage: gwr <remote-base-branch> [worktree-suffix]
set -e

if [ -z "${1:-}" ]; then
    echo "Usage: gwr <remote-base-branch> [worktree-suffix]" >&2
    exit 1
fi

BRANCH_NAME="${1}${2:+_${2}}"
REPO_ROOT=$(git rev-parse --show-toplevel)
WORKTREE_DIR="$(dirname "$REPO_ROOT")/$(basename "$REPO_ROOT")-worktrees"
WORKTREE_PATH="$WORKTREE_DIR/$BRANCH_NAME"
mkdir -p "$WORKTREE_DIR"

git fetch --tags --prune-tags origin

# Git refuses to check out a branch twice (main worktree or a previous gwr
# run); point at the existing location and succeed instead.
USED_BY=$(git worktree list --porcelain | awk -v b="refs/heads/$BRANCH_NAME" '
    /^worktree /{p=substr($0,10)}
    $1 == "branch" && $2 == b {print p; exit}')
if [ -n "$USED_BY" ]; then
    echo "[gwr] branch '$BRANCH_NAME' already checked out at: $USED_BY"
    exit 0
fi

git worktree add --track -B "$BRANCH_NAME" "$WORKTREE_PATH" "origin/$1"

# A child process cannot cd the caller's shell: VS Code gets the worktree
# added to its window, everyone else gets the path printed. A missing or
# failing code CLI must not fail the worktree itself.
if [ "${TERM_PROGRAM:-}" = "vscode" ]; then
    if command -v code >/dev/null 2>&1; then
        code --add "$WORKTREE_PATH" || echo "[gwr] error adding worktree to workspace" >&2
    else
        echo "[gwr] error adding worktree to workspace: code not found" >&2
    fi
fi
echo "[gwr] worktree ready: $WORKTREE_PATH"

# Dependency update is secondary to the worktree: report failures without
# failing the git operation.
. /usr/local/share/git-extended/pm_detect.sh
run_pm_check || true
GWR_EOF
chmod 755 "$BIN_DIR/gwr"
else
rm -f "$BIN_DIR/gwr"
fi

echo "git-extended feature installed successfully!"
