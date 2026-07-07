# Cómo publicar el Git Extended Feature en GHCR

## Requisitos previos

1. **Este repositorio debe estar en GitHub** (ej: `tu-usuario/devcontainer-features`)
2. **Los paquetes deben ser públicos** (configuración manual requerida)

## Pasos para publicar

### 1. Configurar visibilidad de paquetes en GitHub

Los paquetes en GHCR son **privados por defecto**. Debes configurarlos como públicos:

1. Ve a tu perfil de GitHub → **Packages**
2. Busca el paquete `git-extended`
3. Haz clic en **Package settings**
4. En "Danger Zone", selecciona **Change visibility** → **Public**
5. Confirma el cambio

### 2. Publicar una nueva versión

#### Opción A: Usando GitHub Actions (Recomendado)

1. Ve a la pestaña **Actions** en tu repositorio
2. Selecciona el workflow **"Release dev container Features"**
3. Haz clic en **Run workflow**
4. El workflow:
   - Publicará automáticamente el feature en GHCR
   - Generará documentación (README.md)
   - Creará un PR con la documentación actualizada

La URL del feature será:
```
ghcr.io/tu-usuario/devcontainer-features/git-extended:1.0.0
```

#### Opción B: Creando un Release en GitHub

1. Ve a **Releases** → **Create a new release**
2. Crea un tag (ej: `v1.0.0`)
3. Publica el release
4. El workflow se ejecutará automáticamente

### 3. Usar el feature en tu proyecto

En tu `.devcontainer/devcontainer.json`:

```jsonc
{
    "features": {
        "ghcr.io/tu-usuario/devcontainer-features/git-extended:1": {
            "installGcrFunction": true,
            "installGwrFunction": true,
            "enablePostCheckout": true
        }
    }
}
```

## Versiones

El feature usa **Semantic Versioning**:

- `1.0.0` - Versión específica
- `1.0` - Última versión 1.0.x
- `1` - Última versión 1.x.x (recomendado para usuarios)

## Actualizar el feature

1. Modifica `src/git-extended/install.sh` o `devcontainer-feature.json`
2. Actualiza la versión en `devcontainer-feature.json` (ej: `1.0.1`)
3. Ejecuta el workflow de release
4. Los usuarios actualizarán cambiando a la nueva versión

## Estructura del repositorio

```
devcontainer-features/
├── .github/
│   └── workflows/
│       └── release.yaml      # Workflow de publicación
├── src/
│   └── git-extended/
│       ├── devcontainer-feature.json  # Metadata (ID, versión, opciones)
│       ├── install.sh                 # Script de instalación
│       └── README.md                  # Documentación
└── HOW-TO-PUBLISH.md                  # Este archivo
```

## Solución de problemas

### Error: "Package not found"

- Verifica que el paquete sea **público** en GitHub Packages
- Confirma que la URL sea correcta: `ghcr.io/USERNAME/REPO/FEATURE:VERSION`

### Error: "Permission denied"

- El workflow necesita permisos `packages: write`
- Verifica que `.github/workflows/release.yaml` tenga los permisos correctos

### El feature no se instala

- Ejecuta `Rebuild Container` en VS Code
- Verifica que el `devcontainer-feature.json` tenga el `id` correcto
- Revisa los logs del workflow en GitHub Actions

## Más información

- [Dev Container Features Spec](https://containers.dev/implementors/features/)
- [feature-starter template](https://github.com/devcontainers/feature-starter)
- [Publicar en GHCR](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)