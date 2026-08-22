#!/bin/bash
set -e

# Esta librería es inyectada automáticamente por el CLI de DevContainers
source dev-container-features-test-lib

# Verificamos que el contenedor base tenga dotnet
check "dotnet está disponible" dotnet --info

# Finaliza el test y reporta el resultado
reportResults