# RPG Pixel Art Dark Fantasy

RPG de mundo abierto en primera persona para celular **en vertical**, con estética pixel art y rivales con memoria. Hecho con **Godot 4.7.2** (GDScript con tipado estático). Plataforma inicial: Android.

Estado: **Fase 0**. Proyecto base + escena de prueba (cubo girando + FPS) + pipeline de releases.

## Descargar y probar en tu Android

1. Desde el celular, entra a la pestaña **Releases** del repo y descarga el `.apk` más reciente.
2. Ábrelo. La primera vez Android pide permitir "instalar apps desconocidas" para tu navegador o gestor de archivos.
3. Si el release dice "firmado con llave de debug temporal", desinstala la versión anterior antes de instalar.

## Abrir el proyecto en tu computadora (opcional)

1. Descarga Godot **4.7.2 estándar** (no la versión .NET) desde godotengine.org.
2. Abre Godot > Import > selecciona `project.godot`.
3. F5 corre el juego en una ventana vertical de 405x720. Con el mouse se simula el touch.

La carpeta `.godot/` es caché que el editor regenera (como `node_modules` o `.next`). No se sube al repo.

## Estructura (por feature)

| Carpeta | Qué va ahí |
|---|---|
| `player/` | Jugador: movimiento, cámara en primera persona, controles táctiles |
| `rivals/` | Rivales con memoria: `RivalData`, `RivalMemory`, IA |
| `piedra/` | La piedra mágica: poder, lectura (scouter), memoria del mundo |
| `combat/` | Componentes de combate reutilizables: vida, hitbox/hurtbox |
| `world/` | Niveles y zonas. `world/demo/` tiene la escena de prueba de la fase 0 |
| `ui/` | HUD y menús. `ui/safe_area/` respeta notch y barra de gestos |
| `core/` | Autoloads (`Piedra`, `SaveService`) cuando lleguen |
| `assets/` | Arte y audio compartido entre features |
| `tools/ci/` | Scripts que usa GitHub Actions |
| `docs/` | Guías y notas de diseño |

Cada feature junta su escena (`.tscn`), su script (`.gd`) y sus recursos, igual que un componente de React junta JSX, estilos y tests.

## Cómo se publica un release

Lo explica a detalle [`docs/flujo-de-releases.md`](docs/flujo-de-releases.md). En corto:

1. Cada avance llega como **pull request**. GitHub Actions corre un smoke test y construye un APK de prueba (queda como artifact del run).
2. Si el PR sube la versión en `project.godot` (`application/config/version`), al hacer merge a `main` se publica el **GitHub Release `vX.Y.Z`** con el APK firmado.

## Guía de Godot para devs web

Ver [`docs/godot-para-devs-web.md`](docs/godot-para-devs-web.md).
