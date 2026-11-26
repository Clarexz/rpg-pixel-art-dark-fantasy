# Flujo de releases para Android

Es el mismo flujo que usarías con una app Android nativa. Godot exporta APKs desde la línea de comandos (modo `--headless`, sin ventana), así que corre perfecto en GitHub Actions.

## Qué pasa en cada evento

| Evento | Qué hace el workflow `Android build` |
|---|---|
| Pull request | Importa assets, corre el smoke test, exporta APK y lo deja como **artifact** del run (14 días). No publica nada. |
| Push / merge a `main` | Lo mismo, y si la versión de `project.godot` no tiene release todavía, crea el **GitHub Release `vX.Y.Z`** con el APK. |
| Manual (Actions > Android build > Run workflow) | En `main` publica. En otra rama solo deja el artifact. |

El **smoke test** corre el juego sin ventana 300 frames y falla si Godot imprime errores de script o de carga. Es el equivalente a "¿al menos compila y arranca?".

## Versiones

La única fuente de verdad es `application/config/version` en `project.godot` (formato `X.Y.Z`). El script `tools/ci/version.sh` la copia al preset de Android y calcula el `versionCode` que exige Android:

```
versionCode = X*10000 + Y*100 + Z      0.3.1 -> 301
```

Android solo instala una actualización encima de otra si el `versionCode` sube **y** está firmada con la misma llave.

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
