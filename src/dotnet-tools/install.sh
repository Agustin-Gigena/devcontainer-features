#!/usr/bin/env bash
set -e

# DevContainers inyecta las opciones en mayúsculas
TOOLS_LIST=${TOOLS:-""}
TARGET_DIR="/usr/local/share/dotnet-tools"

if [ -z "$TOOLS_LIST" ]; then
    echo "No se especificaron herramientas .NET para instalar."
    exit 0
fi

# Verificar si el SDK de dotnet está instalado
if ! command -v dotnet &> /dev/null; then
    echo "Error: El CLI de 'dotnet' no se encuentra. Asegúrate de instalar el SDK de .NET antes de ejecutar este feature."
    exit 1
fi

echo "Creando directorio destino: $TARGET_DIR"
mkdir -p "$TARGET_DIR"
chmod 755 "$TARGET_DIR"

# Convertir la lista separada por comas en un array
IFS=',' read -r -a TOOLS_ARRAY <<< "$TOOLS_LIST"

for tool in "${TOOLS_ARRAY[@]}"; do
    # Limpiar espacios en blanco
    tool=$(echo "$tool" | xargs)
    
    if [ -n "$tool" ]; then
        echo "Instalando herramienta .NET: $tool"
        # Instalamos forzando la ruta global compartida
        dotnet tool install "$tool" --tool-path "$TARGET_DIR"
    fi
done

# Asegurar que cualquier usuario pueda ejecutar los binarios instalados
chmod -R 755 "$TARGET_DIR"

echo "¡Instalación de herramientas .NET completada!"