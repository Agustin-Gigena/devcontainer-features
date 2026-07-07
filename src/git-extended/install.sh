#!/bin/sh
set -e

echo "Activating feature 'git-extended'"

# Environment variables from options (set by dev container CLI)
INSTALL_GCR_FUNCTION=${INSTALLGCRFUNCTION:-true}
INSTALL_GWR_FUNCTION=${INSTALLGWRFUNCTION:-true}
ENABLE_POST_CHECKOUT=${ENABLEPOSTCHECKOUT:-true}

# User environment
REMOTE_USER_HOME="${_REMOTE_USER_HOME:-/home/vscode}"
CONTAINER_USER_HOME="${_CONTAINER_USER_HOME:-/home/vscode}"

# Detect shell profile files
if [ -n "$ZSH_VERSION" ] || [ -f "$REMOTE_USER_HOME/.zshrc" ]; then
    PROFILE="$REMOTE_USER_HOME/.zshrc"
    SHELL_TYPE="zsh"
else
    PROFILE="$REMOTE_USER_HOME/.bashrc"
    SHELL_TYPE="bash"
fi

# Create directory for git-extended scripts
GIT_EXTENDED_DIR="/usr/local/git-extended"
mkdir -p "$GIT_EXTENDED_DIR"

# Write pm_detect.sh - Package manager auto-detection
cat > "$GIT_EXTENDED_DIR/pm_detect.sh" << 'PM_DETECT_EOF'
#!/bin/sh
# pm_detect.sh - Detección Automática de Gestores de Paquetes
# Ejecutar tras operaciones de git (checkout, clone, pull)

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
        echo "[WARN] No es un repositorio git, omitiendo detección" >&2
        return 0
    }
    
    FOUND=0
    echo "$PM_DETECTORS" | while IFS=: read -r KEY DETECT_FILE INSTALL_CMD; do
        [ -z "$KEY" ] && continue
        
        if find "$REPO_ROOT" -maxdepth 3 -name "$DETECT_FILE" 2>/dev/null | grep -q .; then
            FOUND=1
            echo "Detección: ${KEY} - ${INSTALL_CMD}"
            (cd "$REPO_ROOT" && eval "$INSTALL_CMD") || { 
                echo "[ERROR] Falló: ${INSTALL_CMD}" >&2
                continue
            }
        fi
    done
    
    if [ "$FOUND" -eq 1 ]; then
        echo "Instalación de dependencias completada"
    fi
}

# Ejecutar si se llama directamente
if [ "${1:-}" = "--run" ]; then
    run_pm_check
fi
PM_DETECT_EOF

chmod +x "$GIT_EXTENDED_DIR/pm_detect.sh"

# Install gcr and gwr functions if requested
if [ "$INSTALL_GCR_FUNCTION" = "true" ] || [ "$INSTALL_GWR_FUNCTION" = "true" ]; then
    echo "Installing git functions..."
    
    mkdir -p "$GIT_EXTENDED_DIR/functions"
    
    # GCR - Git Checkout Remote
    if [ "$INSTALL_GCR_FUNCTION" = "true" ]; then
        cat > "$GIT_EXTENDED_DIR/functions/gcr.sh" << 'GCR_EOF'
# gcr - Git Checkout Remote
# Uso: gcr <remote-branch> [nombre-rama-local]
gcr() {
    local REMOTE='origin'
    
    if [ -z "${1}" ]; then
        echo "gcr creates a new branch based on a ${REMOTE} branch.
    If the branch already exists it is reseted.

    Usage:
        gcr <${REMOTE} base branch> [name-for-new-branch]
    Example:
            gcr development new-feature
        will result in the creation of the branch development_new-feature
        tracking ${REMOTE}/development
"
        return
    fi

    local BRANCH_NAME=''
    if [ -z "$2" ]; then
        BRANCH_NAME="${1}"
    else
        BRANCH_NAME="${1}_${2}"
    fi

    git fetch -t -P "${REMOTE}" &&
    git checkout -t "${REMOTE}/${1}" -B "${BRANCH_NAME}" &&

    # Auto-run package detection
    if [ -f /usr/local/git-extended/pm_detect.sh ]; then
        . /usr/local/git-extended/pm_detect.sh
        run_pm_check
    fi
}
GCR_EOF
        
        echo "" >> "$PROFILE"
        echo "# Git Extended - gcr function" >> "$PROFILE"
        echo ". $GIT_EXTENDED_DIR/functions/gcr.sh" >> "$PROFILE"
        echo "gcr function installed in $PROFILE"
    fi
    
    # GWR - Git Worktree Remote
    if [ "$INSTALL_GWR_FUNCTION" = "true" ]; then
        cat > "$GIT_EXTENDED_DIR/functions/gwr.sh" << 'GWR_EOF'
# gwr - Git Worktree Remote
# Crea un worktree nuevo basado en una rama remota
# Uso: gwr <remote-branch> [nombre-worktree]
gwr() {
    local REMOTE='origin'
    
    if [ -z "${1}" ]; then
        echo "gwr creates a new worktree based on a ${REMOTE} branch.
    If the worktree already exists it is reseted.

    Usage:
        gwr <${REMOTE} base branch> [name-for-new-worktree]
    Example:
            gwr development new-feature
        will result in the creation of the worktree development_new-feature
        (inside ../<repo-name>-worktrees/development_new-feature)
        tracking ${REMOTE}/development
"
        return
    fi

    local BRANCH_NAME=''
    if [ -z "$2" ]; then
        BRANCH_NAME="${1}"
    else
        BRANCH_NAME="${1}_${2}"
    fi

    # Worktree directory (sibling to current repo)
    local REPO_ROOT
    REPO_ROOT="$(git rev-parse --show-toplevel)"
    local WORKTREE_DIR="${REPO_ROOT}/../$(basename "${REPO_ROOT}")-worktrees"
    mkdir -p "${WORKTREE_DIR}"

    git fetch -t -P "${REMOTE}" &&
    git worktree add --track -B "${BRANCH_NAME}" "${WORKTREE_DIR}/${BRANCH_NAME}" "${REMOTE}/${1}" &&

    # If in VS Code, open the worktree
    if [ "$TERM_PROGRAM" = "vscode" ]; then
        code --add "${WORKTREE_DIR}/${BRANCH_NAME}"
    fi

    cd "${WORKTREE_DIR}/${BRANCH_NAME}" || return 1 &&

    # Auto-run package detection in new worktree
    if [ -f /usr/local/git-extended/pm_detect.sh ]; then
        . /usr/local/git-extended/pm_detect.sh
        run_pm_check
    fi
}
GWR_EOF
        
        echo "" >> "$PROFILE"
        echo "# Git Extended - gwr function" >> "$PROFILE"
        echo ". $GIT_EXTENDED_DIR/functions/gwr.sh" >> "$PROFILE"
        echo "gwr function installed in $PROFILE"
    fi
fi

# Install post-checkout hook if requested
if [ "$ENABLE_POST_CHECKOUT" = "true" ]; then
    echo "Installing git post-checkout hook..."
    
    GLOBAL_HOOKS_DIR="$GIT_EXTENDED_DIR/hooks"
    mkdir -p "$GLOBAL_HOOKS_DIR"
    
    cat > "$GLOBAL_HOOKS_DIR/post-checkout" << 'HOOK_EOF'
#!/bin/sh
# post-checkout hook - Auto package installation
PREVIOUS_HEAD="$1"
NEW_HEAD="$2"
BRANCH_CHECKOUT="$3"

# Only on branch checkout (not file checkout)
[ "$BRANCH_CHECKOUT" != "1" ] && exit 0

if [ -f /usr/local/git-extended/pm_detect.sh ]; then
    echo ">>> git post-checkout: Detectando paquetes..."
    . /usr/local/git-extended/pm_detect.sh
    run_pm_check
fi
HOOK_EOF
    
    chmod +x "$GLOBAL_HOOKS_DIR/post-checkout"
    
    echo "To enable post-checkout hooks globally, run:"
    echo "  git config --global core.hooksPath $GLOBAL_HOOKS_DIR"
fi

# Copy scripts to user's home for easy access
mkdir -p "$REMOTE_USER_HOME/bin"
cp "$GIT_EXTENDED_DIR/pm_detect.sh" "$REMOTE_USER_HOME/bin/pm_detect"
chmod +x "$REMOTE_USER_HOME/bin/pm_detect"

echo "git-extended feature installed successfully!"
echo "  - pm_detect: $REMOTE_USER_HOME/bin/pm_detect"
echo "  - gcr function: ${INSTALL_GCR_FUNCTION:-false}"
echo "  - gwr function: ${INSTALL_GWR_FUNCTION:-false}"
echo "  - post-checkout hook: ${ENABLE_POST_CHECKOUT:-false}"