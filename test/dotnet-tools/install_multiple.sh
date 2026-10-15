#!/bin/bash
set -e
source dev-container-features-test-lib

# Validamos que dotnet-ef responda a su comando
check "dotnet-ef está instalado y en el PATH" dotnet ef --version

# Validamos que csharpier esté en el PATH
check "csharpier está instalado y en el PATH" csharpier --help

# Validar físicamente que estén en la ruta global que definimos
check "los binarios están en el directorio correcto" ls -l /usr/local/share/dotnet-tools/dotnet-ef

reportResults
