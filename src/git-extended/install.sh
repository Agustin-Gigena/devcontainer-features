#!/bin/sh
set -e

echo "Activating feature 'git-extended'"

INSTALL_GCR_FUNCTION="${INSTALLGCRFUNCTION:-true}"
INSTALL_GWR_FUNCTION="${INSTALLGWRFUNCTION:-true}"
ENABLE_POST_CHECKOUT="${ENABLEPOSTCHECKOUT:-true}"

GIT_EXTENDED_DIR="/usr/local/git-extended"
mkdir -p "$GIT_EXTENDED_DIR/functions"

cat > "$GIT_EXTENDED_DIR/pm_detect.sh" << 'PM_DETECT_EOF'
#!/bin/sh
# pm_detect.sh - Automatic Package Manager Detection

PM_DETECTORS="
npm:package.json:npm install --save-exact
composer:composer.json:composer install
dotnet:*.csproj:dotnet restore
dotnet:*.sln:dotnet restore
bundle:Gemfile:bundle install
cargo:Cargo.toml:cargo build
"

run_pm_check() {
    REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
        echo "[WARN] Not a git repository, skipping package detection" >&2
        return 0
    }

    FOUND=0
    while IFS=: read -r KEY DETECT_FILE INSTALL_CMD; do
        [ -z "$KEY" ] && continue

        if find "$REPO_ROOT" -maxdepth 3 -name "$DETECT_FILE" -not -path '*/.*' 2>/dev/null | grep -q .; then
            FOUND=1
            echo "Detected: ${KEY} -> Executing: ${INSTALL_CMD}"
            (cd "$REPO_ROOT" && eval "$INSTALL_CMD") || {
                echo "[ERROR] Failed: ${INSTALL_CMD}" >&2
                continue
            }
        fi
    done <<EOF
$PM_DETECTORS
EOF

    if [ "$FOUND" -eq 1 ]; then
        echo "Dependency installation completed"
    fi
}

if [ "${1:-}" = "--run" ]; then
    run_pm_check
fi
PM_DETECT_EOF

chmod +x "$GIT_EXTENDED_DIR/pm_detect.sh"

if [ "$INSTALL_GCR_FUNCTION" = "true" ]; then
    cat > "$GIT_EXTENDED_DIR/functions/gcr.sh" << 'GCR_EOF'
gcr() {
    local REMOTE='origin'
    if [ -z "${1}" ]; then
        echo "Usage: gcr <remote-base-branch> [new-branch-suffix]"
        return 1
    fi
    local BRANCH_NAME="${1}${2:+_${2}}"

    git fetch -t -P "${REMOTE}" && \
    git checkout -t "${REMOTE}/${1}" -B "${BRANCH_NAME}" && \
    if [ -f /usr/local/git-extended/pm_detect.sh ]; then
        . /usr/local/git-extended/pm_detect.sh
        run_pm_check
    fi
}
GCR_EOF
fi

if [ "$INSTALL_GWR_FUNCTION" = "true" ]; then
    cat > "$GIT_EXTENDED_DIR/functions/gwr.sh" << 'GWR_EOF'
gwr() {
    local REMOTE='origin'
    if [ -z "${1}" ]; then
        echo "Usage: gwr <remote-base-branch> [worktree-suffix]"
        return 1
    fi
    local BRANCH_NAME="${1}${2:+_${2}}"

    local REPO_ROOT
    REPO_ROOT="$(git rev-parse --show-toplevel)" || return 1
    local WORKTREE_DIR="${REPO_ROOT}/../$(basename "${REPO_ROOT}")-worktrees"
    mkdir -p "${WORKTREE_DIR}"

    git fetch -t -P "${REMOTE}" && \
    git worktree add --track -B "${BRANCH_NAME}" "${WORKTREE_DIR}/${BRANCH_NAME}" "${REMOTE}/${1}" && \

    if [ "$TERM_PROGRAM" = "vscode" ]; then
        code --add "${WORKTREE_DIR}/${BRANCH_NAME}"
    fi

    cd "${WORKTREE_DIR}/${BRANCH_NAME}" || return 1

    if [ -f /usr/local/git-extended/pm_detect.sh ]; then
        . /usr/local/git-extended/pm_detect.sh
        run_pm_check
    fi
}
GWR_EOF
fi

PROFILE_SCRIPT="/etc/profile.d/git-extended.sh"
cat > "$PROFILE_SCRIPT" << 'PROFILE_EOF'
# Git Extended Functions Loading
if [ -d "/usr/local/git-extended/functions" ]; then
    for f in /usr/local/git-extended/functions/*.sh; do
        [ -r "$f" ] && . "$f"
    done
fi
PROFILE_EOF
chmod +x "$PROFILE_SCRIPT"

if [ "$ENABLE_POST_CHECKOUT" = "true" ]; then
    GLOBAL_HOOKS_DIR="$GIT_EXTENDED_DIR/hooks"
    mkdir -p "$GLOBAL_HOOKS_DIR"

    cat > "$GLOBAL_HOOKS_DIR/post-checkout" << 'HOOK_EOF'
#!/bin/sh
PREVIOUS_HEAD="$1"
NEW_HEAD="$2"
BRANCH_CHECKOUT="$3"

[ "$BRANCH_CHECKOUT" != "1" ] && exit 0

if [ -f /usr/local/git-extended/pm_detect.sh ]; then
    echo ">>> git post-checkout: Detecting packages..."
    . /usr/local/git-extended/pm_detect.sh
    run_pm_check
fi
HOOK_EOF

    chmod +x "$GLOBAL_HOOKS_DIR/post-checkout"

    git config --system core.hooksPath "$GLOBAL_HOOKS_DIR" || true
fi

cat > "/usr/local/bin/pm_detect" << 'PM_DETECT_CLI_EOF'
#!/bin/sh
. /usr/local/git-extended/pm_detect.sh
run_pm_check
PM_DETECT_CLI_EOF
chmod +x "/usr/local/bin/pm_detect"

echo "git-extended feature installed successfully!"
