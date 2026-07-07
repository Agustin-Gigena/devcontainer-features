# Tests para Git Extended Feature

## Estructura de tests

```
test/git-extended/
├── test.sh                 # Tests básicos de instalación
├── integration-test.sh     # Tests de funcionalidad
└── scenarios.json          # Escenarios para pruebas con diferentes opciones
```

## Ejecutar tests localmente

### Requisitos
```bash
npm install -g @devcontainers/cli
```

### Todos los tests
```bash
devcontainer features test .
```

### Solo el feature git-extended
```bash
devcontainer features test ./src/git-extended
```

### Con una imagen específica
```bash
devcontainer features test ./src/git-extended --base-image "mcr.microsoft.com/devcontainers/base:ubuntu"
```

### Solo escenarios
```bash
devcontainer features test --global-scenarios-only ./test/git-extended
```

## Escenarios disponibles

El archivo `scenarios.json` define 6 escenarios:

1. **default_options** - Todas las opciones en sus valores por defecto
2. **all_features_enabled** - Explícitamente todas activas
3. **only_gcr** - Solo función gcr habilitada
4. **only_gwr** - Solo función gwr habilitada
5. **all_disabled** - Todas las funciones deshabilitadas
6. **debian_test** - Test en base image Debian

## Tests incluidos

### test.sh (Tests básicos)
- ✅ pm_detect.sh existe y es ejecutable
- ✅ pm_detect helper está en ~/bin
- ✅ gcr函数 source file existe
- ✅ gcr cargada en .bashrc
- ✅ gwr函数 source file existe
- ✅ gwr cargada en .bashrc
- ✅ post-checkout hook existe y es ejecutable
- ✅ Las funciones pueden ser sourceadas

### integration-test.sh (Tests de funcionalidad)
- ✅ gcr muestra ayuda sin argumentos
- ✅ gwr muestra ayuda sin argumentos
- ✅ pm_detect detecta npm en repo de prueba
- ✅ pm_detect ejecuta npm install correctamente

## CI/CD

Los tests se ejecutan automáticamente en GitHub Actions:
- En cada push a `main`
- En cada pull request
- Manualmente vía workflow dispatch

Ver resultados en: **Actions** → **Test Dev Container Features**

## Agregar nuevos tests

Para agregar un nuevo test:

1. **Agrega un check en test.sh**:
```bash
check "descripción del test" comando_a_ejecutar
```

2. **O agrega un nuevo escenario en scenarios.json**:
```json
{
  "mi_nuevo_escenario": {
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
      "git-extended": {
        "installGcrFunction": false
      }
    }
  }
}
```

## Depurar tests fallidos

Para depurar un test:

1. Construye el contenedor manualmente:
```bash
devcontainer build --workspace-folder . --image-name test-git-extended
```

2. Ejecuta el contenedor:
```bash
docker run -it test-git-extended bash
```

3. Ejecuta los tests manualmente dentro del contenedor:
```bash
source dev-container-features-test-lib
check "mi test" comando
reportResults
```