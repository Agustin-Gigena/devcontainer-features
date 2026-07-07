# Repository Guidelines

## Project Overview

This repository is a **Dev Container Features** template for creating and publishing custom dev container features. It follows the [dev container Feature specification](https://containers.dev/implementors/features/) and distributes features via GitHub Container Registry (GHCR).

The example contains two simple features:
- **hello**: Prints a greeting message with customizable text
- **color**: Outputs a favorite color from configurable options

## Architecture & Data Flow

### High-Level Structure

```
devcontainer-features/
├── src/                    # Feature definitions (one folder per feature)
│   ├── hello/             # Greeting feature implementation
│   ├── color/             # Color output feature implementation
│   └── <feature-name>/    # Template for new features
├── test/                   # Test scenarios and scripts
│   ├── _global/           # Cross-feature integration tests
│   ├── hello/             # hello feature tests
│   └── color/             # color feature tests
├── .github/workflows/     # CI/CD automation
│   ├── release.yaml       # Publish to GHCR + generate docs
│   ├── test.yaml          # Run feature tests
│   └── validate.yml       # Validate feature schemas
├── .devcontainer/         # Development environment config
└── README.md              # Collection documentation
```

### Build & Runtime Flow

1. **Development**: Features are defined in `src/<feature>/` using shell scripts
2. **Validation**: PRs trigger schema validation via `validate.yml`
3. **Testing**: Features are tested in containers using `test.yaml`
4. **Publishing**: Manual workflow dispatch publishes to GHCR and generates documentation
5. **Consumption**: Dev container CLI downloads features from GHCR and executes install scripts

### Feature Execution

```
devcontainer.json → devcontainer CLI → OCI registry (GHCR) → Container build → install.sh script
```

## Key Directories

| Directory | Purpose |
|-----------|---------|
| `src/<feature>/` | Feature implementation: `devcontainer-feature.json` (metadata) + `install.sh` (entrypoint) |
| `test/<feature>/` | Feature-specific tests with scenarios.json for option variations |
| `test/_global/` | Cross-feature integration tests |
| `.github/workflows/` | GitHub Actions for validation, testing, and release |

## Development Commands

### Testing Features

```bash
# Run all feature tests
devcontainer features test /path/to/repo

# Test specific feature
devcontainer features test --features hello /path/to/repo

# Test with specific user context
devcontainer features test --features hello --remote-user root /path/to/repo

# Run global scenario tests
devcontainer features test --global-scenarios-only /path/to/repo

# Full test command with base image
devcontainer features test --features color --remote-user root --skip-scenarios \
  --base-image mcr.microsoft.com/devcontainers/base:ubuntu /path/to/repo
```

### Validation

Validation runs automatically on PRs via `.github/workflows/validate.yml` - no local command needed.

### Publishing

Publishing is automated via GitHub Actions workflow dispatch:
1. Navigate to **Actions** tab → **Release dev container features & Generate Documentation**
2. Click **Run workflow**
3. Workflow publishes to GHCR and creates PR for documentation updates

### Local Development Setup

```bash
# Install devcontainer CLI for testing
npm install -g @devcontainers/cli

# No package.json in repo - CLI installed globally
```

## Code Conventions & Common Patterns

### Feature Definition (`devcontainer-feature.json`)

```jsonc
{
    "name": "Feature Name",
    "id": "feature-id",           // Matches folder name in src/
    "version": "1.0.2",           // SemVer per feature
    "description": "...",
    "type": "binary",             // Optional: "binary" or "script"
    "options": {                  // User-configurable options
        "optionName": {
            "type": "string",
            "enum": ["opt1", "opt2"],
            "default": "opt1",
            "description": "..."
        }
    },
    "installsAfter": [            // Dependencies
        "ghcr.io/devcontainers/features/common-utils"
    ]
}
```

### Install Script Patterns (`install.sh`)

```bash
#!/bin/sh
set -e  # Always exit on error

# Feature-scoped environment variables from options
GREETING=${GREETING:-default_value}

# Use effective user environment variables (passed by devcontainer CLI)
echo "Remote user: $_REMOTE_USER"

# Create executable
cat > /usr/local/bin/command << EOF
#!/bin/sh
# Command implementation with environment variable expansion
echo "\${GREETING}"
EOF

chmod +x /usr/local/bin/command
```

**Key Patterns:**
- Use `set -e` for error handling
- Options become uppercased environment variables (`greeting` → `$GREETING`)
- Environment variable expansion in heredocs requires `\${VAR}` escaping
- Scripts run as root by default
- Install binaries to `/usr/local/bin/`

### Test Script Patterns

```bash
#!/bin/bash
set -e

source dev-container-features-test-lib  # Provides check, reportResults

# Comparison function
check "test description" command | grep "expected output"

# Report all test results
reportResults
```

### Naming Conventions

- **Feature folders**: lowercase, hyphenated (`feature-name`)
- **Script files**: lowercase with `.sh` extension
- **Options**: camelCase in JSON, UPPERCASE in shell scripts
- **Test files**: `<scenario>.sh` or `test.sh`

## Important Files

| File | Purpose |
|------|---------|
| `src/hello/devcontainer-feature.json` | Feature metadata and options definition |
| `src/hello/install.sh` | Feature installation script (executed at container build time) |
| `test/color/test.sh` | Unit tests for color feature |
| `test/_global/scenarios.json` | Multi-feature test scenarios |
| `.devcontainer/devcontainer.json` | Development container configuration |
| `.github/workflows/release.yaml` | Automated publishing pipeline |

## Runtime & Tooling Preferences

### Runtime Requirements

- **Shell**: POSIX-compatible `/bin/sh` for install scripts, `bash` for tests (4.0+)
- **Registry**: GHCR (GitHub Container Registry)
- **Package Manager**: No JS/Node.js tooling - pure shell scripts and OCI distribution
- **Container Base Images**: Typically `mcr.microsoft.com/devcontainers/base:ubuntu` or `alpine`

### Tooling Constraints

- **No build step**: Features are distributed as-is (no compilation, no bundling)
- **Install script constraints**: Runs once at container build time, no interactive prompts
- **No runtime configuration**: All configuration happens via `devcontainer-feature.json` options

### Local Development Setup

```bash
# Required for testing
npm install -g @devcontainers/cli

# VS Code extension for schema validation
# Extension ID: mads-hartmann.bash-ide-vscode
```

## Testing & QA
### Documentation Generation

Feature READMEs are auto-generated by the release workflow from `devcontainer-feature.json`:
- **Format**: Markdown with YAML frontmatter
- **Sections**: Feature name, description, Example Usage JSON, Options table (Id | Description | Type | Default)
- **Footer**: Note linking to source JSON with instructions to add `NOTES.md` for custom content
- **Location**: `src/<feature>/README.md` (committed by release workflow PR)

### Test Framework

- **Library**: `dev-container-features-test-lib` (bundled with CLI)
- **Commands**: `check`, `reportResults`, `skip`, `fail`
- **Structure**: Each feature has dedicated test folder with `test.sh` and `scenarios.json`

### Test Organization

**Unit Tests** (`test/<feature>/test.sh`):
- Test default option behavior
- Validate command output with grep assertions

**Scenario Tests** (`test/<feature>/scenarios.json`):
- Test specific option combinations
- Cross-feature scenarios test multiple features together

**Global Tests** (`test/_global/`):
- Integration tests spanning multiple features
- Test interaction between features

### Running Tests

```bash
# Run feature tests (default skips scenarios)
devcontainer features test --features color /path/to/repo

# Include scenario tests
devcontainer features test --features color --skip-scenarios=false /path/to/repo
```

### Coverage Expectations

- Each feature must have at least one test validating default options
- Options with enums should test each possible value via scenarios
- Global scenarios test feature interactions
- Tests run in GitHub Actions on PRs via `test.yaml` workflow

### CI Workflow

Pull requests trigger:
1. **Validation**: Schema validation of all `devcontainer-feature.json` files
2. **Testing**: Execute test suites for affected features
3. **Manual Release**: Workflow dispatch publishes new versions

---

## Adding a New Feature

1. Create `src/<feature-name>/` folder
2. Add `devcontainer-feature.json` with metadata and options
3. Add `install.sh` with installation logic
4. Create test folder: `test/<feature-name>/`
5. Add `test.sh` and `scenarios.json`
6. Test locally with `devcontainer features test --features <feature-name> .`
7. Commit changes and create PR

## AI Assistant Notes

- Features are **declarative**: options in JSON → environment variables in shell
- Failures should point to **script logic** or **option configuration**, not runtime dependencies
- Test output uses `check` command format: `check "<description>" <command>`
- Version changes require updating `version` field in `devcontainer-feature.json` (not package.json)