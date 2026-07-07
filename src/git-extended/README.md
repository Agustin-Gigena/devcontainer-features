# Git Extended Feature

A Dev Container Feature that provides git workflow enhancements with automatic package manager detection.

## What it does

- **gcr function**: Checkout remote branches with automatic dependency installation
- **gwr function**: Create git worktrees from remote branches with VS Code integration
- **pm_detect**: Auto-detect and install dependencies for npm, composer, .NET, bundler, cargo
- **post-checkout hook**: Automatically install dependencies when switching branches

## Example Usage

```jsonc
{
    "features": {
        "ghcr.io/your-org/devcontainer-features/git-extended:1": {
            "installGcrFunction": true,
            "installGwrFunction": true,
            "enablePostCheckout": true
        }
    }
}
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `installGcrFunction` | boolean | `true` | Install the `gcr` shell function for remote branch checkout |
| `installGwrFunction` | boolean | `true` | Install the `gwr` shell function for git worktree creation |
| `enablePostCheckout` | boolean | `true` | Enable automatic package installation on git checkout |

## Commands

### `gcr <remote-branch> [local-branch-name]`

Checkout a remote branch and automatically install dependencies:

```bash
gcr development new-feature
# Creates branch 'development_new-feature' tracking origin/development
```

### `gwr <remote-branch> [worktree-name]`

Create a git worktree from a remote branch:

```bash
gwr development new-feature
# Creates worktree in ../<repo-name>-worktrees/development_new-feature
# Opens in VS Code if running inside the IDE
# Automatically installs dependencies
```

### `pm_detect`

Manually trigger package detection:

```bash
pm_detect
# or
pm_detect --run
```

## Supported Package Managers

- **npm**: `package.json` → `npm install --save-exact`
- **Composer**: `composer.json` → `composer install`
- **.NET**: `*.csproj` / `*.sln` → `dotnet restore`
- **Bundler**: `Gemfile` → `bundle install`
- **Cargo**: `Cargo.toml` → `cargo build`

## Worktree Structure

When using `gwr`, worktrees are created in a sibling directory:

```
my-project/
my-project-worktrees/
├── development_feature-a/
├── develop_feature-b/
└── main_hotfix/
```

## Post-Checkout Hook

To enable automatic dependency installation on every branch checkout, configure git to use the global hooks:

```bash
git config --global core.hooksPath /usr/local/git-extended/hooks
```

## Based on

This feature is based on the git functions from [iyaki/dotfiles](https://github.com/iyaki/dotfiles/blob/main/.bash_functions).

## License

MIT