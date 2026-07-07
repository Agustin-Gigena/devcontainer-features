# Git Extended Feature Design

**Date:** 2026-07-07  
**Author:** AI Assistant  
**Status:** Approved

## Overview

This design specifies a Dev Container Feature called `git-extended` that provides enhanced git workflow functions (`gcr`, `gwr`) with automatic project deployment capabilities across multiple package managers and shell environments.

## Problem Statement

The original `gcr` (git checkout remote) and `gwr` (git worktree remote) functions from [iyaki/dotfiles](https://github.com/iyaki/dotfiles/blob/main/.bash_functions) are limited to:
- Bash shell only
- Only npm and composer for package management
- No cross-shell compatibility
- Hardcoded `project_deploy()` with limited detector logic

This Feature extends that functionality to work across bash/zsh/fish shells and automatically detect and install dependencies for 10+ package managers.

## Architecture

### Feature Structure

```
src/git-extended/
├── devcontainer-feature.json    # Feature manifest with options
├── install.sh                    # Main installation script
└── scripts/
    ├── bash_functions.sh         # Bash/zsh function definitions
    ├── fish_functions.fish       # Fish function definitions
    ├── bash_completion.sh        # Bash completion functions
    └── fish_completions.fish     # Fish completion functions
```

### Components

#### 1. Core Functions

**`gcr <remote-branch> [new-branch-name]`**
- Fetches remote branches
- Creates/updates local branch tracking remote
- Calls `project_deploy()` for automatic dependency installation
- If no `new-branch-name` provided, uses the remote branch name

**`gwr <remote-branch> [new-branch-name]`**
- Creates git worktree in `../<repo-name>-worktrees/<branch-name>`
- Opens in VS Code if running in VS Code terminal
- Changes directory to new worktree
- Calls `project_deploy()` for automatic dependency installation

**`project_deploy()`**
- Scans repository root for known project files
- Executes install command for EACH detected package manager
- Runs sequentially to avoid resource conflicts
- Silent failure for missing package managers (graceful degradation)

#### 2. Package Manager Detection Matrix

| Package Manager | Detector File(s) | Install Command | Install Prerequisites |
|----------------|------------------|-----------------|----------------------|
| npm | `package.json` | `npm install --save-exact` | nodejs, npm |
| composer | `composer.json` | `composer install` | php, composer |
| dotnet | `*.csproj`, `*.sln`, `*.slnx` | `dotnet restore` | dotnet-sdk |
| pip | `requirements.txt` | `pip install -r requirements.txt` | python3, pip |
| poetry | `pyproject.toml` (with poetry section) | `poetry install` | python3, poetry |
| bundler | `Gemfile` | `bundle install` | ruby, bundler |
| cargo | `Cargo.toml` | `cargo build` | rust, cargo |
| go | `go.mod` | `go mod download` | golang |
| maven | `pom.xml` | `mvn dependency:resolve` | java, maven |
| gradle | `build.gradle` or `build.gradle.kts` | `gradle dependencies` | java, gradle |

#### 3. Shell Compatibility

**Bash/Zsh:**
- Functions stored in `~/.bash_functions` (sourced by `~/.bashrc` or `~/.zshrc`)
- Completion functions: `__remote_branch_completion`
- Standard POSIX-compatible function syntax

**Fish:**
- Functions stored in `~/.config/fish/functions/`
- Fish-native syntax (no POSIX compatibility needed)
- Fish completion system for completions

### Installation Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    install.sh                               │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│   Detect &    │  │   Install     │  │   Generate    │
│   Install     │  │   Shell       │  │   Shell       │
│   Prereqs     │  │   Functions   │  │   Completions │
└───────────────┘  └───────────────┘  └───────────────┘
        │                   │                   │
        │                   ▼                   ▼
        │           ┌───────────────────────────────┐
        │           │   ~ / .bash_functions         │
        │           │   ~ / .config/fish/           │
        │           │   ~ / .zshrc (source)         │
        │           └───────────────────────────────┘
        ▼
┌───────────────────────┐
│  Package Managers:    │
│  - npm (if needed)    │
│  - composer (if needed)│
│  - dotnet (if needed) │
│  - etc...             │
└───────────────────────┘
```

### Data Flow

```
User executes: gcr main my-feature
        │
        ▼
┌───────────────────────────────┐
│  gcr()                        │
│  1. fetch origin              │
│  2. checkout -t origin/main   │
│  3. project_deploy()          │
└───────────────────────────────┘
        │
        ▼
┌───────────────────────────────┐
│  project_deploy()             │
│  1. scan for project files    │
│  2. for each detected:        │
│     - npm install             │
│     - composer install        │
│     - dotnet restore          │
│     - etc...                  │
└───────────────────────────────┘
        │
        ▼
┌───────────────────────────────┐
│  Project ready with all       │
│  dependencies installed       │
└───────────────────────────────┘
```

## Error Handling

### Graceful Degradation

- If a detected package manager is not installed, log warning but continue
- If git worktree already exists, reset it (original behavior)
- If VS Code is not available, skip `code --add` command silently

### Error Conditions

1. **No git repository**: Functions exit with clear error message
2. **Remote branch not found**: Display fetch error and available branches
3. **Worktree directory conflict**: Delete existing worktree or suggest alternative name (TBD - user preference)
4. **Package manager command fails**: Log error, continue with other managers

### Logging

- All install commands show their output (no silent failures)
- Warnings prefixed with `[git-extended WARN]`
- Errors prefixed with `[git-extended ERROR]`

## Testing Strategy

### Test Scenarios

1. **Single package manager project** (e.g., only Node.js)
2. **Multi-package manager project** (e.g., Node.js + PHP)
3. **No recognized project files** (bare git repo)
4. **Worktree creation and navigation**
5. **Shell compatibility** (bash, zsh, fish)
6. **Completion functionality** (tab-completion for remote branches)

### Test Approach

The Tester agent will author tests that verify:
- Functions are available after container build
- `project_deploy()` correctly detects and installs dependencies
- `gcr` and `gwr` perform expected git operations
- Shell completions are functional

## Dependencies

### Required
- Git (assumed present in base image)

### Optional (auto-installed if needed)
- Node.js + npm
- PHP + Composer  
- .NET SDK
- Python + pip/poetry
- Ruby + Bundler
- Rust + Cargo
- Go
- Java + Maven/Gradle

## Configuration

### devcontainer-feature.json Options

```jsonc
{
  "options": {}
}
```

**Note:** This Feature has NO required options. It auto-detects and installs everything needed. This follows the "zero configuration, works by default" principle.

### Future Option Ideas (NOT in scope)

- `installPackageManagers`: boolean to disable auto-install
- `deployOnCheckout`: boolean to disable automatic project_deploy
- `verbosity`: string for log level (silent, normal, verbose)

These can be added later if user feedback indicates need.

## Performance Considerations

### Build Time Impact

- Detection logic is O(n) where n = number of package manager types (10)
- Each package manager install runs sequentially
- Package managers are cached by the container system (OCI layers)

### Runtime Impact

- `project_deploy()` scans 10 file patterns per call (negligible)
- Install commands only run when needed (post-checkout worktree)
- No background processes or daemons

## Security Considerations

- All package managers install dependencies from their respective registries
- No elevation of privileges required
- Commands run as the user in the container
- No network exposure or services started

## Documentation

### README.md Sections

1. **Feature Overview** - What this provides
2. **Usage** - Example `gcr` and `gwr` commands
3. **Supported Package Managers** - Table of detectors and commands
4. **Shell Compatibility** - Which shells are supported
5. **Configuration** - Options (currently none)
6. **Examples** - devcontainer.json snippets

### Function Documentation

Each function will include inline documentation accessible via:
- `gcr --help` (no args shows help)
- `gwr --help` (no args shows help)

## Migration Path

### From Original bash_functions

Users migrating from the original iyaki/dotfiles implementation:
1. Remove `.bash_functions` sourcing from their config
2. Add this Feature to devcontainer.json
3. Functions have same names and basic usage
4. `project_deploy()` now supports more package managers

### Breaking Changes

- None - this is additive functionality
- Existing `gcr`/`gwr` calls work identically

## Open Questions

### TBD: Worktree Conflict Resolution

When worktree already exists:
- **Option A:** Delete and recreate (destructive)
- **Option B:** Git reset --hard (keeps git state, destroys local changes)
- **Option C:** Error and suggest different name (safe but inconvenient)

**Recommendation:** Option B (git reset --hard) with optional force flag for Option A. This matches typical worktree workflows where the worktree is disposable.

---

## Changelog

- **2026-07-07:** Initial design, approved by user
  - Added slnx support for dotnet
  - Removed `gw` function (only `gcr` and `gwr`)
  - Auto-detect and install all needed package managers
  - Shell support: bash, zsh, fish
  - Autocomplete included