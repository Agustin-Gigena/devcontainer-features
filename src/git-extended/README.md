
# Git Extended (git-extended)

Git workflow extensions: gcr/gwr checkout and worktree commands, plus pm_detect which updates dependencies for every package manager found in the repository

## Example Usage

```json
"features": {
    "ghcr.io/Agustin-Gigena/devcontainer-features/git-extended:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| installGcrFunction | Install the gcr (Git Checkout Remote) command | boolean | true |
| installGwrFunction | Install the gwr (Git Worktree Remote) command | boolean | true |
| pkgManager | Comma-separated managers pm_detect may run (npm, pnpm, yarn, bun, dotnet, composer, bundle, cargo). Unset = detect automatically. | string | - |
| worktreePath | Directory where gwr creates worktrees. Relative paths resolve against the current directory; unset = .worktrees in the current directory. | string | - |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/Agustin-Gigena/devcontainer-features/blob/main/src/git-extended/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
