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

# Per-manager brand color for the dependency lines.
mgr_color() {
    case "$1" in
        npm)      printf '\033[31m' ;;
        pnpm)     printf '\033[93m' ;;
        yarn)     printf '\033[34m' ;;
        bun)      printf '\033[35m' ;;
        dotnet)   printf '\033[94m' ;;
        composer) printf '\033[33m' ;;
        bundle)   printf '\033[91m' ;;
        cargo)    printf '\033[92m' ;;
    esac
}

run_pm_check() {
    REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
        echo "dependencies: not inside a git repository, skipping" >&2
        return 0
    }

    # Colors + spinner only on interactive terminals; pipes and CI keep the
    # plain streaming output so logs stay greppable and complete.
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != dumb ]; then
        TTY=yes
        C_G=$(printf '\033[32m'); C_R=$(printf '\033[31m'); C_Y=$(printf '\033[33m')
        C_C=$(printf '\033[36m'); C_D=$(printf '\033[2m'); C_B=$(printf '\033[1m'); C_0=$(printf '\033[0m')
        OUT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/pm_detect.XXXXXX") || OUT_DIR=
        if [ -n "$OUT_DIR" ]; then trap 'rm -rf "$OUT_DIR"' EXIT; fi
        printf '\n%s%s── dependencies ─ %s%s%s\n' "$C_B" "$C_C" "$C_D" "$REPO_ROOT" "$C_0"
    else
        TTY=no; C_G=; C_R=; C_Y=; C_C=; C_D=; C_B=; C_0=
    fi

    # Single scan pass; pruned dirs keep vendored/nested copies from
    # triggering installs (e.g. node_modules/*/package.json).
    FOUND=$(cd "$REPO_ROOT" && find . -maxdepth 6 \
        \( -name .git -o -name node_modules -o -name vendor -o -name target -o -name bin -o -name obj \) -prune -o -type f \
        \( -name package.json -o -name pnpm-lock.yaml -o -name yarn.lock -o -name bun.lock -o -name bun.lockb \
           -o -name '*.csproj' -o -name '*.fsproj' -o -name '*.sln' -o -name '*.slnx' \
           -o -name composer.json -o -name Gemfile -o -name Cargo.toml \
        \) -print 2>/dev/null) || true

    # One install per marker directory: in monorepos the manager runs where
    # the project lives, not at the repo root.
    QUEUE=""
    SEEN=""
    while IFS= read -r F; do
        [ -z "$F" ] && continue
        DIR=$(dirname "$F")
        case "$F" in
            *.csproj|*.fsproj|*.sln|*.slnx) CMD="dotnet restore" ;;
            */composer.json) CMD="composer install" ;;
            */Gemfile) CMD="bundle install" ;;
            */Cargo.toml) CMD="cargo fetch" ;;
            */package.json)
                if [ -f "$REPO_ROOT/$DIR/pnpm-lock.yaml" ]; then CMD="pnpm install"
                elif [ -f "$REPO_ROOT/$DIR/yarn.lock" ]; then CMD="yarn install"
                elif [ -f "$REPO_ROOT/$DIR/bun.lock" ] || [ -f "$REPO_ROOT/$DIR/bun.lockb" ]; then CMD="bun install"
                else CMD="npm install"; fi ;;
            *) continue ;;  # lockfiles only pick the manager for their sibling package.json
        esac
        ENTRY="$DIR|$CMD"
        case "$SEEN" in *"$ENTRY"*) continue ;; esac
        SEEN="$SEEN
$ENTRY"
        QUEUE="$QUEUE
$ENTRY"
    done <<EOF
$FOUND
EOF

    if [ -z "$QUEUE" ]; then
        echo "${C_D}no known package manager files found${C_0}"
        return 0
    fi

    FAILED=0; OK=0; BAD=0; T0=$(date +%s); N=0
    while IFS= read -r ENTRY; do
        [ -z "$ENTRY" ] && continue
        DIR=${ENTRY%%|*}
        CMD=${ENTRY#*|}
        MGR=${CMD%% *}
        MC=
        if [ "$TTY" = yes ]; then MC=$(mgr_color "$MGR"); fi
        if ! command -v "$MGR" >/dev/null 2>&1; then
            echo "${C_Y}WARN: $MGR not installed, skipping: $CMD${C_0}" >&2
            continue
        fi
        if [ "$TTY" = yes ] && [ -n "$OUT_DIR" ]; then
            # Spinner while the command runs; its output is captured and the
            # last lines are shown on failure.
            N=$((N+1)); OUT="$OUT_DIR/$N.log"
            START=$(date +%s)
            (cd "$REPO_ROOT/$DIR" && eval "$CMD" < /dev/null) >"$OUT" 2>&1 &
            PID=$!; I=0
            while kill -0 "$PID" 2>/dev/null; do
                # npm-style braille dot spinner (cli-spinners "dots")
                case $((I % 10)) in
                    0) S='⠋' ;; 1) S='⠙' ;; 2) S='⠹' ;; 3) S='⠸' ;; 4) S='⠼' ;;
                    5) S='⠴' ;; 6) S='⠦' ;; 7) S='⠧' ;; 8) S='⠇' ;; 9) S='⠏' ;;
                esac
                printf '\r%s%s %s%s%s %s(%s)%s  ' "$C_C" "$S" "$MC" "$CMD" "$C_0" "$C_D" "$DIR" "$C_0"
                I=$((I+1)); sleep 0.08 2>/dev/null || sleep 1
            done
            RC=0; wait "$PID" || RC=$?
            DUR=$(( $(date +%s) - START ))
            printf '\033[2K\r'
            if [ "$RC" -eq 0 ]; then
                OK=$((OK+1))
                printf '%s%s✔%s %s%s%s %s(%s · %ss)%s\n' "$C_B" "$C_G" "$C_0" "$MC" "$CMD" "$C_0" "$C_D" "$DIR" "$DUR" "$C_0"
            else
                BAD=$((BAD+1)); FAILED=1
                printf '%s%s✘ failed: %s%s%s %s(%s)%s\n' "$C_B" "$C_R" "$MC" "$CMD" "$C_0" "$C_D" "$DIR" "$C_0"
                printf '%s' "$C_D"
                tail -n 5 "$OUT" | sed 's/^/    /'
                printf '%s\n' "$C_0"
            fi
        else
            echo "$CMD ($DIR)"
            if (cd "$REPO_ROOT/$DIR" && eval "$CMD" < /dev/null); then
                OK=$((OK+1))
            else
                BAD=$((BAD+1)); FAILED=1
                echo "ERROR: failed: $CMD ($DIR)" >&2
            fi
        fi
    done <<EOF
$QUEUE
EOF

    TOT=$(( $(date +%s) - T0 ))
    if [ "$TTY" = yes ]; then
        if [ "$FAILED" -eq 1 ]; then
            printf '%s%s✗ dependency update finished with errors%s %s(%s ok · %s failed · %ss)%s\n' "$C_B" "$C_R" "$C_0" "$C_D" "$OK" "$BAD" "$TOT" "$C_0"
        else
            printf '%s%s✔ dependency update completed%s %s(%s ok · %ss)%s\n' "$C_B" "$C_G" "$C_0" "$C_D" "$OK" "$TOT" "$C_0"
        fi
    else
        if [ "$FAILED" -eq 1 ]; then
            echo "dependency update finished with errors" >&2
        else
            echo "dependency update completed"
        fi
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
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != dumb ]; then
    C_C=$(printf '\033[36m'); C_0=$(printf '\033[0m')
else
    C_C=; C_0=
fi

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
    echo "${C_C}[gcr] WARNING: '$BRANCH_NAME' has $UNPUBLISHED commit(s) not on origin/$1${C_0}" >&2
    echo "${C_C}[gcr] resetting discards them from the branch; recover with: git reflog${C_0}" >&2
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
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != dumb ]; then
    C_C=$(printf '\033[36m'); C_B=$(printf '\033[1m'); C_0=$(printf '\033[0m')
else
    C_C=; C_B=; C_0=
fi

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
    echo "${C_C}[gwr] branch '$BRANCH_NAME' already checked out at: $USED_BY${C_0}"
    exit 0
fi

git worktree add --track -B "$BRANCH_NAME" "$WORKTREE_PATH" "origin/$1"

# A child process cannot cd the caller's shell: VS Code gets the worktree
# added to its window, everyone else gets the path printed. A missing or
# failing code CLI must not fail the worktree itself.
if [ "${TERM_PROGRAM:-}" = "vscode" ]; then
    if command -v code >/dev/null 2>&1; then
        code --add "$WORKTREE_PATH" || echo "${C_C}[gwr] error adding worktree to workspace${C_0}" >&2
    else
        echo "${C_C}[gwr] error adding worktree to workspace: code not found${C_0}" >&2
    fi
fi
echo "${C_B}${C_C}[gwr] worktree ready: $WORKTREE_PATH${C_0}"

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
