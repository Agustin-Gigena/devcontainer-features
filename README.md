# Dev Container Features Collection

A collection of dev container features for common development workflows. Each feature follows the Dev Container Feature specification and can be published to GitHub Container Registry (GHCR) for reuse in devcontainer.json files.

## Features in this repository

- Git Extended (`git-extended`) — shell helpers for working with remote branches and worktrees, plus optional package-manager detection for installing project dependencies.
- .NET Global Tools (`dotnet-tools`) — install selected .NET global tools (for example: `dotnet-ef`, `dotnet-stryker`, `csharpier`) into the container for all users.

## Using published features (recommended)

Features published to GHCR can be referenced from your devcontainer.json:

```jsonc
{
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {
    "ghcr.io/Agustin-Gigena/devcontainer-features/git-extended:1": {
      "installGcrFunction": true,
      "installGwrFunction": true
    },
    "ghcr.io/Agustin-Gigena/devcontainer-features/dotnet-tools:1": {
      "tools": "dotnet-ef,csharpier"
    }
  }
}
```

Use a major tag like `:1` to follow the latest v1.x release, or pin to a specific semver (for example `:1.0.0`).

## Using features from source (development)

To test or use features directly from this repository during development, reference the local feature folder in your devcontainer.json:

```jsonc
{
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {
    "./src/git-extended": {},
    "./src/dotnet-tools": { "tools": "dotnet-ef" }
  }
}
```

## Repository layout

```
devcontainer-features/
├── README.md
├── src/                  # Feature source directories
│   ├── git-extended/
│   │   ├── devcontainer-feature.json
│   │   ├── install.sh
│   │   └── README.md
│   └── dotnet-tools/
│       ├── devcontainer-feature.json
│       ├── install.sh
│       └── README.md
├── test/                 # Feature tests and test scenarios
└── .github/workflows/    # CI: validate, test, release
```

## Development

Install the Dev Containers CLI to run tests locally:

```bash
npm install -g @devcontainers/cli
```

Run feature tests:

```bash
# Test everything in the repository
devcontainer features test .

# Test a single feature
devcontainer features test ./src/git-extended
```

CI workflows in `.github/workflows/` validate each feature schema and run containerized tests. Releases are produced by the repository's release workflow and publish feature packages to GHCR.

## Contributing

Contributions are welcome. Please open an issue or submit a pull request with your changes. When adding new features follow the pattern in `src/` and add tests to `test/`.

## License

This repository is licensed under the MIT License. See the LICENSE file for details.

---

Collection published at: `ghcr.io/Agustin-Gigena/devcontainer-features`
