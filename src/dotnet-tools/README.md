# .NET Global Tools (dotnet-tools)

Installs one or more .NET global tools into a shared directory so they are available to all users inside the dev container.

This feature depends on the base .NET SDK being available and installs the requested tools into `/usr/local/share/dotnet-tools`. The install path is added to `PATH` automatically via the feature configuration.

## Example usage

```jsonc
{
  "features": {
    "ghcr.io/Agustin-Gigena/devcontainer-features/dotnet-tools:1": {
      "tools": "dotnet-ef,csharpier"
    }
  }
}
```

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `tools` | string | `""` | Comma-separated list of .NET global tools to install. Examples: `dotnet-ef`, `dotnet-stryker`, `csharpier`, `dotnet-outdated-tool`. |

## Supported examples

The feature accepts a comma-separated list such as:

```jsonc
{
  "tools": "dotnet-ef,dotnet-stryker,csharpier"
}
```

Each tool is installed with:

```bash
dotnet tool install <tool-name> --tool-path /usr/local/share/dotnet-tools
```

## Notes

- This feature exits cleanly if no tools are specified.
- If the `dotnet` CLI is not installed, the installation fails with an explicit error.
- Installed binaries become available in the container environment through the configured `PATH` entry.
