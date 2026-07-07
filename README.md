# Dev Container Features Collection

A collection of custom [Dev Container Features](https://containers.dev/implementors/features/) for enhancing development container workflows.

## Features

### 🚀 Git Extended (`git-extended`)

Git workflow enhancements with automatic package manager detection and dependency installation.

**Capabilities:**
- `gcr` - Git Checkout Remote: Checkout remote branches with automatic dependency installation
- `gwr` - Git Worktree Remote: Create Git worktrees from remote branches with VS Code integration
- `pm_detect` - Auto-detect and install dependencies for npm, Composer, .NET, Bundler, and Cargo
- Post-checkout hook: Automatically install dependencies on every branch checkout

**Example Usage:**
```jsonc
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/Agustin-Gigena/devcontainer-features/git-extended:1": {
            "installGcrFunction": true,
            "installGwrFunction": true,
            "enablePostCheckout": true
        }
    }
}
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `installGcrFunction` | boolean | `true` | Install the `gcr` shell function |
| `installGwrFunction` | boolean | `true` | Install the `gwr` shell function |
| `enablePostCheckout` | boolean | `true` | Enable automatic package installation on git checkout |

📚 [Full Documentation](src/git-extended/README.md)

## Usage

### Using Published Features (Recommended)

Features are published to the GitHub Container Registry (GHCR) and can be used in your `.devcontainer/devcontainer.json`:

```jsonc
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/Agustin-Gigena/devcontainer-features/git-extended:1": {
            "installGcrFunction": true
        }
    }
}
```

Features follow [Semantic Versioning](https://semver.org/). Use `:1` for the latest v1.x.x, or pin to a specific version like `:1.0.0`.

### Using Features from Source

To use features directly from this repository during development:

```jsonc
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "./src/git-extended": {}
    }
}
```

## Repository Structure

This repository follows the [Dev Container Feature distribution specification](https://containers.dev/implementors/features-distribution/):

```
.
├── README.md
├── src/
│   └── git-extended/           # Feature source code
│       ├── devcontainer-feature.json
│       ├── install.sh
│       └── README.md
├── test/
│   └── git-extended/           # Feature tests
│       └── test.sh
└── .github/
    └── workflows/
        ├── release.yaml        # Publishes features to GHCR
        └── test.yaml           # Runs feature tests
```

Each feature in `src/` contains:
- `devcontainer-feature.json` - Feature metadata and options
- `install.sh` - Installation script (executed as root during container build)
- `README.md` - Feature-specific documentation

## Development

### Testing Features

To test features locally, install the Dev Container CLI:

```bash
npm install -g @devcontainers/cli
```

Then run tests:

```bash
# Test all features
devcontainer features test .

# Test a specific feature
devcontainer features test ./src/git-extended

# Test with a specific base image
devcontainer features test --base-image "mcr.microsoft.com/devcontainers/base:debian" ./src/git-extended
```

### Publishing Features

Features are automatically published to GHCR when you:

1. Create a new release on GitHub
2. Run the "Release dev container Features" workflow manually from the Actions tab

The workflow will:
- Build and publish each feature to GHCR
- Generate/update documentation
- Create a PR with documentation updates

⚠️ **Important:** After publishing, navigate to each feature's package settings in GHCR and mark it as **Public** (to stay within the free tier).

### Creating New Features

To add a new feature to this collection:

1. Create a new directory in `src/<feature-id>/`
2. Add `devcontainer-feature.json` with metadata
3. Add `install.sh` with installation logic
4. Create corresponding tests in `test/<feature-id>/`
5. Test locally before publishing

## Learn More

- [Dev Container Features Specification](https://containers.dev/implementors/features/)
- [Features Distribution Specification](https://containers.dev/implementors/features-distribution/)
- [Official Feature Starter Template](https://github.com/devcontainers/feature-starter)
- [Dev Container CLI Documentation](https://github.com/devcontainers/cli)

## License

MIT - See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

---

**Collection published at:** `ghcr.io/Agustin-Gigena/devcontainer-features`  
**Features indexed on:** [containers.dev](https://containers.dev/features)