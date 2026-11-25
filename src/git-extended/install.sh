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

# True when $1 is in the PKGMANAGER allow-list (empty list = everything).
mgr_allowed() {
    [ -z "$ALLOWED" ] && return 0
    for a in $ALLOWED; do
        [ "$a" = "$1" ] && return 0
    done
    return 1
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

    # Option PKGMANAGER: comma-separated allow-list of managers to run.
    ALLOWED=
    if [ -n "${PKGMANAGER:-}" ]; then
        ALLOWED=$(printf '%s' "$PKGMANAGER" | tr ',' ' ')
    fi

    # Single scan pass; pruned dirs keep vendored/nested copies from
    # triggering installs (e.g. node_modules/*/package.json).
    FOUND=$(cd "$REPO_ROOT" && find . -maxdepth 6 \
        \( -name .git -o -name node_modules -o -name vendor -o -name target -o -name bin -o -name obj -o -name .worktrees -o -name cdk.out -o -name dist -o -name build \) -prune -o -type f \
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
            *.csproj|*.fsproj|*.sln|*.slnx) MGR=dotnet; CMD="dotnet restore" ;;
            */composer.json) MGR=composer; CMD="composer install" ;;
            */Gemfile) MGR=bundle; CMD="bundle install" ;;
            */Cargo.toml) MGR=cargo; CMD="cargo fetch" ;;
            */package.json)
                if [ -f "$REPO_ROOT/$DIR/pnpm-lock.yaml" ]; then MGR=pnpm; CMD="pnpm install"
                elif [ -f "$REPO_ROOT/$DIR/yarn.lock" ]; then MGR=yarn; CMD="yarn install"
                elif [ -f "$REPO_ROOT/$DIR/bun.lock" ] || [ -f "$REPO_ROOT/$DIR/bun.lockb" ]; then MGR=bun; CMD="bun install"
                else MGR=npm; CMD="npm install"; fi ;;
            *) continue ;;  # lockfiles only pick the manager for their sibling package.json
        esac
        mgr_allowed "$MGR" || continue
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
# gcr - move to a branch; create it from origin when it does not exist.
# Usage: gcr <branch> [suffix]
set -e
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != dumb ]; then
    C_C=$(printf '\033[36m'); C_0=$(printf '\033[0m')
else
    C_C=; C_0=
fi

if [ -z "${1:-}" ]; then
    echo "Usage: gcr <branch> [suffix]" >&2
    exit 1
fi

BRANCH_NAME="${1}${2:+_${2}}"

if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    # The branch already exists locally: move to it without touching origin.
    USED_BY=$(git worktree list --porcelain | awk -v b="refs/heads/$BRANCH_NAME" '
        /^worktree /{p=substr($0,10)}
        $1 == "branch" && $2 == b {print p; exit}')
    if [ -n "$USED_BY" ] && [ "$USED_BY" != "$(pwd)" ]; then
        echo "[gcr] branch '$BRANCH_NAME' is checked out at: $USED_BY" >&2
        echo "[gcr] cd to that directory to work on it" >&2
        exit 1
    fi
    git checkout "$BRANCH_NAME"
else
    git fetch --tags --prune-tags origin
    git checkout -t "origin/$1" -B "$BRANCH_NAME"
fi

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

# Bash completion: branch names for gcr/gwr (local branches for gwr -D).
mkdir -p /etc/bash_completion.d
cat > /etc/bash_completion.d/git-extended << 'COMPLETION_EOF'
# bash completion for gcr/gwr (Git Extended)
_git_ext_branches() {
    {
        git for-each-ref --format='%(refname:short)' refs/heads
        git for-each-ref --format='%(refname:short)' refs/remotes/origin \
            | sed -e 's|^origin/||' -e '/^HEAD$/d'
    } | sort -u
}
_gcr_completion() {
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=($(compgen -W "$(_git_ext_branches)" -- "$cur"))
}
_gwr_completion() {
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"
    if [ "$COMP_CWORD" -eq 2 ] && [ "${COMP_WORDS[1]}" = "-D" ]; then
        COMPREPLY=($(compgen -W "$(git branch --format='%(refname:short)' 2>/dev/null)" -- "$cur"))
        return
    fi
    COMPREPLY=($(compgen -W "$(_git_ext_branches) -D -f" -- "$cur"))
}
complete -F _gcr_completion gcr
complete -F _gwr_completion gwr
COMPLETION_EOF

if [ "$INSTALL_GWR" = "true" ]; then
cat > "$BIN_DIR/gwr" << 'GWR_EOF'
#!/bin/sh
# gwr - create a git worktree tracking a remote base branch.
# Usage: gwr [-D [-f]] <remote-base-branch> [worktree-suffix]
#        gwr -D <branch> removes the worktree; -f discards local changes.
set -e
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != dumb ]; then
    C_C=$(printf '\033[36m'); C_B=$(printf '\033[1m'); C_0=$(printf '\033[0m')
else
    C_C=; C_B=; C_0=
fi

if [ -z "${1:-}" ]; then
    echo "Usage: gwr [-D [-f]] <remote-base-branch> [worktree-suffix]" >&2
    echo "       gwr -D <branch> removes the worktree (-f discards local changes)" >&2
    exit 1
fi

DELETE=no; FORCE=no
while [ "${1:-}" = "-D" ] || [ "${1:-}" = "-f" ]; do
    [ "$1" = "-D" ] && DELETE=yes
    [ "$1" = "-f" ] && FORCE=yes
    shift
done
if [ -z "${1:-}" ]; then
    echo "Usage: gwr -D [-f] <remote-base-branch> [worktree-suffix]" >&2
    exit 1
fi

BRANCH_NAME="${1}${2:+_${2}}"
# Project root: option ROOT overrides git auto-detection (absolute, or
# relative to the detected git root). Worktrees live under it, never beside
# it: with repos mounted at / the old sibling scheme hit permission errors.
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || REPO_ROOT=
BASE_ROOT="$REPO_ROOT"
if [ -n "${ROOT:-}" ]; then
    case "$ROOT" in
        /*) BASE_ROOT="$ROOT" ;;
        *) BASE_ROOT="${REPO_ROOT:-$PWD}/$ROOT" ;;
    esac
fi
if [ -z "$BASE_ROOT" ]; then
    echo "[gwr] not inside a git repository and no root option set" >&2
    exit 1
fi
# Option worktreePath: absolute, or relative to the project root; empty
# keeps the default .worktrees directory at the root.
if [ -n "${WORKTREEPATH:-}" ]; then
    case "$WORKTREEPATH" in
        /*) WORKTREE_DIR="$WORKTREEPATH" ;;
        *) WORKTREE_DIR="$BASE_ROOT/$WORKTREEPATH" ;;
    esac
else
    WORKTREE_DIR="$BASE_ROOT/.worktrees"
fi
WORKTREE_PATH="$WORKTREE_DIR/$BRANCH_NAME"

# Keep the multi-root workspace file at the project root in sync: the
# worktree folder entry is added on creation and dropped on removal. An
# existing *.code-workspace is edited; none is created (root + worktree).
# Entries are single-line; VS Code parses workspace files as JSONC, so the
# trailing comma left when the last worktree entry is removed is fine.
ws_sync() {
    ADD=$1
    REL="$WORKTREE_PATH"
    case "$REL" in
        "$BASE_ROOT"/*) REL="${REL#"$BASE_ROOT"/}" ;;
    esac
    WS_FILE=
    for f in "$BASE_ROOT"/*.code-workspace; do
        if [ -e "$f" ]; then WS_FILE="$f"; break; fi
    done
    if [ -z "$WS_FILE" ]; then
        WS_FILE="$BASE_ROOT/$(basename "$BASE_ROOT").code-workspace"
        printf '{\n    "folders": [\n        { "path": "." }\n    ]\n}\n' > "$WS_FILE"
    fi
    if [ "$ADD" = yes ]; then
        grep -qF "\"path\": \"$REL\"" "$WS_FILE" && return 0
        awk -v e="{ \"path\": \"$REL\" }" '
            {
                if (ins) { print; next }
                if ($0 ~ /"folders"[[:space:]]*:[[:space:]]*\[/) {
                    if ($0 ~ /\]/) {
                        sub(/\]/, "\n        " e "\n    ]")
                        print; ins = 1; next
                    }
                    print
                    if ((getline nxt) > 0) {
                        if (nxt ~ /^[[:space:]]*\]/) { print "        " e; print nxt }
                        else { print "        " e ","; print nxt }
                        ins = 1
                    } else ins = 1
                    next
                }
                print
            }
        ' "$WS_FILE" > "$WS_FILE.tmp" && mv "$WS_FILE.tmp" "$WS_FILE"
    else
        grep -vF "\"path\": \"$REL\"" "$WS_FILE" | sed 's/, *\]/ ]/' > "$WS_FILE.tmp" && mv "$WS_FILE.tmp" "$WS_FILE"
    fi
}

if [ "$DELETE" = yes ]; then
    if [ ! -d "$WORKTREE_PATH" ]; then
        echo "[gwr] worktree not found: $WORKTREE_PATH" >&2
        exit 1
    fi
    if [ "$FORCE" = yes ]; then
        git worktree remove --force "$WORKTREE_PATH"
    elif ! git worktree remove "$WORKTREE_PATH" 2>/dev/null; then
        echo "[gwr] worktree has uncommitted or untracked changes; discard them with: gwr -D -f $BRANCH_NAME" >&2
        exit 1
    fi
    ws_sync no
    echo "${C_B}${C_C}[gwr] worktree removed: $WORKTREE_PATH${C_0}"
    exit 0
fi
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

# A child process cannot cd the caller's shell: VS Code tracks the worktree
# through the workspace file above, everyone else gets the path printed.
if command -v code >/dev/null 2>&1; then
    code --add "$WORKTREE_PATH" 2>/dev/null || true
else
    echo "${C_Y}[gwr] tip: install the 'code' CLI so worktrees are added to your VS Code window automatically${C_0}" >&2
fi
ws_sync yes
echo "${C_B}${C_C}[gwr] worktree ready: $WORKTREE_PATH${C_0}"

# Dependency update runs inside the new worktree (that is where the user
# will work) and is secondary to the git operation: report, never fail gwr.
. /usr/local/share/git-extended/pm_detect.sh
(cd "$WORKTREE_PATH" && run_pm_check) || true
GWR_EOF
chmod 755 "$BIN_DIR/gwr"
else
rm -f "$BIN_DIR/gwr"
fi

echo "git-extended feature installed successfully!"
