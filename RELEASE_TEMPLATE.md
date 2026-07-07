name: Git Extended
version: 1.0.0
description: Git workflow extensions with automatic package manager detection

## What's Included

### `gcr` - Git Checkout Remote
Checkout remote branches with automatic dependency installation.

```bash
gcr development new-feature
# Creates branch 'development_new-feature' tracking origin/development
# Automatically installs npm/composer/dotnet/bundle/cargo dependencies
```

### `gwr` - Git Worktree Remote
Create git worktrees from remote branches with VS Code integration.

```bash
gwr development new-feature
# Creates worktree in ../<repo>-worktrees/development_new-feature
# Opens in VS Code automatically
# Installs dependencies in the new worktree
```

### `pm_detect` - Package Manager Auto-Detection
Automatically detects and installs dependencies for:
- npm (`package.json`)
- Composer (`composer.json`)
- .NET (`*.csproj`, `*.sln`)
- Bundler (`Gemfile`)
- Cargo (`Cargo.toml`)

### Post-Checkout Hook
Automatically install dependencies when switching branches.

## Usage

```jsonc
{
    "features": {
        "ghcr.io/YOUR_USERNAME/devcontainer-features/git-extended:1": {
            "installGcrFunction": true,
            "installGwrFunction": true,
            "enablePostCheckout": true
        }
    }
}
```

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `installGcrFunction` | `true` | Install the `gcr` shell function |
| `installGwrFunction` | `true` | Install the `gwr` shell function |
| `enablePostCheckout` | `true` | Enable automatic package installation on git checkout |

## Based on

Git functions from [iyaki/dotfiles](https://github.com/iyaki/dotfiles/blob/main/.bash_functions)

---

**Full documentation**: [src/git-extended/README.md](src/git-extended/README.md)