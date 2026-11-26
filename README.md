# RPG Pixel Art Dark Fantasy

RPG de mundo abierto en primera persona para celular **en vertical**, con estética pixel art y rivales con memoria. Hecho con **Godot 4.7.2** (GDScript con tipado estático). Plataforma inicial: Android.

Estado: **v0.3.0, rivales con memoria y piedra (lógica)**. Cada rival aprende solo de sus duelos contigo y la piedra lee su poder: ver [`docs/rivales-y-piedra.md`](docs/rivales-y-piedra.md). Base: prototipo a una mano. Exploración en primera persona con un solo pulgar (libre o por casillas) y un duelo por turnos contra un cubo de prueba que te recuerda. Ver [`docs/prototipo-una-mano.md`](docs/prototipo-una-mano.md). La fase 1 (dos pulgares) sigue disponible en Ajustes: [`docs/fase-1-controles.md`](docs/fase-1-controles.md).

## Descargar y probar en tu Android

1. Desde el celular, entra a la pestaña **Releases** del repo y descarga el `.apk` más reciente.
2. Ábrelo. La primera vez Android pide permitir "instalar apps desconocidas" para tu navegador o gestor de archivos.
3. Si el release dice "firmado con llave de debug temporal", desinstala la versión anterior antes de instalar.

## Abrir el proyecto en tu computadora (opcional)

1. Descarga Godot **4.7.2 estándar** (no la versión .NET) desde godotengine.org.
2. Abre Godot > Import > selecciona `project.godot`.
3. F5 corre el juego en una ventana vertical de 405x720. Con el mouse se simula el touch (un dedo). En la compu también hay teclado: WASD mover, Shift correr, Espacio saltar, F atacar, E piedra, M captura el mouse para mirar, Esc lo suelta.

La carpeta `.godot/` es caché que el editor regenera (como `node_modules` o `.next`). No se sube al repo.

## Estructura (por feature)

| Carpeta | Qué va ahí |
|---|---|
| `player/` | Jugador: movimiento, cámara en primera persona, controles táctiles |
| `rivals/` | Rivales con memoria. Hoy: `RivalMemory` y el cubo de prueba (`rivals/test_cube/`) |
| `piedra/` | La piedra mágica: poder, lectura (scouter), memoria del mundo |
| `combat/` | El duelo por turnos: reglas (`duel.gd`) y su pantalla (`duel_ui.gd`) |
| `world/` | Niveles y zonas. `world/greybox/` es el nivel gris de la fase 1; `world/demo/` el cubo de la fase 0 |
| `ui/` | HUD y menús. `ui/safe_area/` respeta notch y barra de gestos |
| `core/` | Autoloads (globales). Hoy: `Sfx`, sonidos placeholder generados por código |
| `assets/` | Arte y audio compartido entre features |
| `tools/ci/` | Scripts que usa GitHub Actions |
| `tools/tests/` | Pruebas automáticas (p. ej. dedos simulados sobre los controles) |
| `docs/` | Guías y notas de diseño |

Cada feature junta su escena (`.tscn`), su script (`.gd`) y sus recursos, igual que un componente de React junta JSX, estilos y tests.

## Cómo se publica un release

Lo explica a detalle [`docs/flujo-de-releases.md`](docs/flujo-de-releases.md). En corto:

1. Cada avance llega como **pull request**. GitHub Actions corre un smoke test y construye un APK de prueba (queda como artifact del run).
2. Si el PR sube la versión en `project.godot` (`application/config/version`), al hacer merge a `main` se publica el **GitHub Release `vX.Y.Z`** con el APK firmado.

## Guía de Godot para devs web

Ver [`docs/godot-para-devs-web.md`](docs/godot-para-devs-web.md).
