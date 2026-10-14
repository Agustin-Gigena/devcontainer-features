# Git Extended (git-extended)

Git workflow helpers for working with remote branches and worktrees, plus automatic dependency detection for common project ecosystems.

This feature installs shell helpers that make it easier to check out remote branches, create worktrees from remote branches, and detect whether the repository contains dependencies that should be installed automatically.

## Included functionality

- `gcr` — checkout a remote branch and create a local tracking branch from it
- `gwr` — create a git worktree from a remote branch and optionally open it in VS Code
- `pm_detect` — detect project manifests such as `package.json`, `composer.json`, `*.csproj`, `Gemfile`, and `Cargo.toml`, then run the corresponding install command

## Example usage

```jsonc
{
  "features": {
    "ghcr.io/Agustin-Gigena/devcontainer-features/git-extended:1": {
      "installGcrFunction": true,
      "installGwrFunction": true
    }
  }
}
```

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `installGcrFunction` | boolean | `true` | Installs the `gcr` helper for remote branch checkout. |
| `installGwrFunction` | boolean | `true` | Installs the `gwr` helper for remote worktree creation. |

## Behavior

When enabled, the feature adds the helper functions to the shell profile so they are available in interactive sessions.

- `gcr <remote-base-branch> [new-branch-suffix]`
  - fetches remote refs
  - checks out the remote branch into a local branch that tracks it
  - runs package detection in the repository root after checkout

- `gwr <remote-base-branch> [worktree-suffix]`
  - creates a worktree from the remote branch
  - optionally adds the worktree folder to VS Code
  - changes into the new worktree and runs package detection

The dependency detector runs commands such as:

- `npm install --save-exact`
- `composer install`
- `dotnet restore`
- `bundle install`
- `cargo build`

## Notes

This feature is designed for dev containers and assumes a Unix-like shell environment. It is intended to streamline branch and worktree workflows for projects that need their dependencies restored immediately after switching contexts.
