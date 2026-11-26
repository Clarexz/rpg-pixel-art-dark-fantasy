# Flujo de releases para Android

Es el mismo flujo que usarías con una app Android nativa. Godot exporta APKs desde la línea de comandos (modo `--headless`, sin ventana), así que corre perfecto en GitHub Actions.

## Dos tipos de versión

El juego avanza en 6 áreas a la vez (mecánicas, mundo, lore, enemigos, sprites, UI/UX), cada una en su rama. Para no gastar un número de versión por cada mejora chica, hay dos tipos de release:

| Tipo | Ejemplo | Sale de | Para qué |
|---|---|---|---|
| **Build de prueba** (pre-release) | `v0.2.0-enemigos.3` | la rama del área | Que Caleb pruebe en el celular una mejora de un área. No es una versión del juego. |
| **Release oficial** | `v0.2.0`, `v0.2.1` | `main` | Junta las mejoras de varias áreas ya integradas. |

Reglas de los números oficiales (`0.X.Y`):
- **0.X.0** cuando hay un avance notable (un hito: "combate pulido", "primera zona con lore").
- **0.X.Y** para arreglos y ajustes chicos sobre esa versión.

En un build de prueba, `0.X.Y` es la versión oficial **a la que va** esa mejora, `<area>` es la rama y `N` cuenta los builds de prueba de esa área para esa versión.

**Ejemplo de una iteración.** v0.1.0 es la base reiniciada, así que la primera iteración de los hilos apunta a **0.2.0**:

```
v0.2.0-enemigos.1, v0.2.0-enemigos.2, v0.2.0-enemigos.3     (pruebas del hilo de enemigos)
v0.2.0-mecanicas.1 ... v0.2.0-mecanicas.5                   (pruebas del hilo de mecánicas)
... Caleb dice "esto basta para esta iteración" ...
todo se junta en main  ->  sale el release oficial v0.2.0
```

La siguiente iteración usa `v0.3.0-<area>.N`, y así. Un arreglo chico sobre una oficial ya publicada sale como `0.2.1`.

Los releases del prototipo (v0.0.1 a v0.6.3, antes de este esquema) quedaron archivados como `proto-v0.x.y (Prototipo)`. La serie nueva arrancó en **v0.1.0**.

## Qué pasa en cada evento

| Evento | Qué hace el workflow `Android build` |
|---|---|
| Pull request | Importa assets, corre las pruebas, exporta APK y lo deja como **artifact** del run (14 días). No publica nada. |
| Push / merge a `main` | Lo mismo, y si la versión de `project.godot` no tiene release todavía, crea el **release oficial `vX.Y.Z`** con el APK. |
| Manual en `main` (Actions > Android build > Run workflow) | Igual que el push a `main`. |
| Manual en una rama de área | Publica un **build de prueba** `vX.Y.Z-<area>.N` como pre-release. Falla si `vX.Y.Z` ya salió como oficial: primero hay que subir la versión. |
| Manual en otra rama | Solo deja el artifact. |

El **smoke test** corre el juego sin ventana 300 frames y falla si Godot imprime errores de script o de carga. Es el equivalente a "¿al menos compila y arranca?".

### Cómo trabaja un hilo de área
1. En su rama, pone `config/version` en `project.godot` en la versión oficial de la iteración actual (por ejemplo `0.2.0` mientras la última oficial sea `0.1.x`).
2. Cuando tiene algo para probar, corre el workflow a mano en su rama (Claude lo hace con la API de GitHub Actions). Sale `v0.2.0-<area>.N`.
3. Cuando el área queda lista, abre PR a `main`. Si va a salir release oficial, el PR que sube la versión agrega `docs/notas/vX.Y.Z.md` con las notas agrupadas por área (### Mecánicas, ### Enemigos, ### UI/UX...). Si no existe ese archivo, GitHub genera las notas con la lista de PRs.

## Versiones

La única fuente de verdad es `application/config/version` en `project.godot` (formato `X.Y.Z`). El script `tools/ci/version.sh` la copia al preset de Android y calcula el `versionCode` (el número interno que Android compara para saber si algo es "más nuevo"):

```
versionCode = (X*10000 + Y*100 + Z) * 1000 + S
  S = cuenta de TODOS los builds de prueba de esa versión (cualquier área), de 1 a 998
  build de prueba  0.2.0-mecanicas.1 (el 4.º build de prueba de 0.2.0)  ->  200004
  release oficial  0.2.0  (S = 999)                                      ->  200999
```

Así cada build de prueba se instala encima del anterior aunque sea de otra área, y el oficial 0.2.0 se instala encima de todos sus builds de prueba. Android solo instala una actualización encima de otra si el `versionCode` sube **y** está firmada con la misma llave.

## La llave de firma (esto lo haces tú, una sola vez)

Android exige que todo APK esté firmado. Si siempre firmamos con la misma llave, puedes instalar cada versión encima de la anterior sin perder datos. Mientras no configures la llave, el workflow firma con una llave de debug que cambia en cada build: funciona, pero tendrás que desinstalar antes de instalar cada versión.

**Guarda el archivo `.keystore` y la contraseña en un lugar seguro** (gestor de contraseñas). Si los pierdes, no podrás publicar actualizaciones de la misma app en Play Store.

### 1. Crear la llave (en tu Mac)

`keytool` viene con Java. Si tienes Android Studio, está en `"/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"`.

```bash
keytool -genkeypair -v \
  -keystore rpg-pixel-release.keystore \
  -alias rpgpixel \
  -keyalg RSA -keysize 2048 -validity 10000
```

Te pide una contraseña y unos datos (nombre, país). Godot usa **una sola contraseña** para el almacén y la llave, así que si te pregunta una segunda, deja la misma.

### 2. Guardar los 3 secrets en GitHub

En el repo: **Settings > Secrets and variables > Actions > New repository secret**.

| Secret | Valor |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | El archivo en base64. En Mac: `base64 -i rpg-pixel-release.keystore \| pbcopy` y pegas |
| `ANDROID_KEYSTORE_PASSWORD` | La contraseña que elegiste |
| `ANDROID_KEY_ALIAS` | `rpgpixel` (el `-alias` del paso 1) |

Con GitHub CLI es lo mismo:

```bash
base64 -i rpg-pixel-release.keystore | gh secret set ANDROID_KEYSTORE_BASE64
gh secret set ANDROID_KEYSTORE_PASSWORD
gh secret set ANDROID_KEY_ALIAS --body rpgpixel
```

Nunca subas el `.keystore` al repo. El `.gitignore` ya lo bloquea.

## Exportar en local (opcional)

Con el editor abierto: **Project > Export > Android**. La primera vez Godot pide instalar las export templates (Editor > Manage Export Templates) y configurar en **Editor Settings > Export > Android** la ruta del Android SDK y de Java. Para lo diario no lo necesitas: GitHub lo hace.
