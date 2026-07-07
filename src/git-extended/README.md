
# Git Extended (git-extended)

Git workflow extensions with automatic package manager detection and remote branch checkout helpers

## Example Usage

```json
"features": {
    "ghcr.io/Agustin-Gigena/devcontainer-features/git-extended:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| installGcrFunction | Install the gcr (Git Checkout Remote) shell function | boolean | true |
| installGwrFunction | Install the gwr (Git Worktree Remote) shell function | boolean | true |
| enablePostCheckout | Enable automatic package installation on git checkout | boolean | true |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/Agustin-Gigena/devcontainer-features/blob/main/src/git-extended/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._

# Git Extended Feature

A Dev Container Feature that provides Git workflow enhancements with automatic package manager detection and dependency installation.

## Overview

This feature streamlines your development workflow by:

- **Automatically installing dependencies** when checking out branches or creating worktrees
- **Providing shell functions** for efficient remote branch and worktree management
- **Supporting multiple package managers** out of the box

## Features

### `gcr` - Git Checkout Remote
Checkout remote branches with automatic dependency installation.

### `gwr` - Git Worktree Remote  
Create Git worktrees from remote branches with VS Code integration and automatic dependency installation.

### `pm_detect` - Package Manager Auto-Detection
Automatically detect and install dependencies for supported package managers.

### Post-Checkout Hook
Optional Git hook to automatically install dependencies on every branch checkout.

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `installGcrFunction` | boolean | `true` | Install the `gcr` shell function for remote branch checkout |
| `installGwrFunction` | boolean | `true` | Install the `gwr` shell function for Git worktree creation |
| `enablePostCheckout` | boolean | `true` | Enable automatic package installation on Git checkout |

## Commands

### `gcr <remote-branch> [local-branch-name]`

Checkout a remote branch and automatically install dependencies:

```bash
gcr development new-feature
# Creates branch 'development_new-feature' tracking origin/development
# Automatically runs pm_detect to install dependencies
```

### `gwr <remote-branch> [worktree-name]`

Create a Git worktree from a remote branch:

```bash
gwr development new-feature
# Creates worktree in ../<repo>-worktrees/development_new-feature
# Opens in VS Code automatically (if running inside VS Code)
# Automatically installs dependencies
```

### `pm_detect`

Manually trigger package manager detection:

```bash
pm_detect
```

## Supported Package Managers

| Package Manager | Detection File | Install Command |
|----------------|----------------|-----------------|
| **npm** | `package.json` | `npm install --save-exact` |
| **Composer** | `composer.json` | `composer install` |
| **.NET** | `*.csproj`, `*.sln` | `dotnet restore` |
| **Bundler** | `Gemfile` | `bundle install` |
| **Cargo** | `Cargo.toml` | `cargo build` |

## Post-Checkout Hook

To enable automatic dependency installation:

```bash
git config --global core.hooksPath /usr/local/git-extended/hooks
```

## License

MIT

## Credits

Based on Git workflow functions from [iyaki/dotfiles](https://github.com/iyaki/dotfiles/blob/main/.bash_functions).
