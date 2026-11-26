# RPG Pixel Art Dark Fantasy

RPG de mundo abierto en primera persona para celular **en vertical**, con estética pixel art y rivales con memoria. Hecho con **Godot 4.7.2** (GDScript con tipado estático). Plataforma inicial: Android.

Estado: **v0.5.0, combate real (fase 3)**. Tres enemigos en pixel art que patrullan el nivel gris, te ven y te persiguen: el **Carroñero** (rápido, combos), el **Gólem de escoria** (lento, golpe cargado) y el **Lobo de ceniza**, el rival que te recuerda (fintas). Items guardados con botín, y huir depende de lo que lee tu piedra. Ver [`docs/combate-real.md`](docs/combate-real.md).

Cómo se juega (sin cambios desde v0.2.0): exploración en primera persona con **un pulgar** y duelos **por turnos con botones**: menú Cuerpo a cuerpo / Hechizos / Items / Huir, cuadrícula 2x3 (abajo atacas con PA, arriba bloqueas), hechizos como "canciones". Ver [`docs/prototipo-una-mano.md`](docs/prototipo-una-mano.md).

Versiones anteriores: v0.4.0 pipeline pixel art ([`docs/pipeline-pixel-art.md`](docs/pipeline-pixel-art.md)), v0.3.0 rivales con memoria y piedra ([`docs/rivales-y-piedra.md`](docs/rivales-y-piedra.md)), v0.1.0 controles a dos pulgares, aún en Ajustes ([`docs/fase-1-controles.md`](docs/fase-1-controles.md)).

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
| `enemies/` | Enemigos en el mundo (`enemy.gd`: patrulla, persigue, animaciones), sus fichas (`enemies/data/`) y sprites |
| `rivals/` | Rivales con memoria: `RivalData`, `RivalMemory`, tácticas y saludos. Fichas en `rivals/data/` |
| `items/` | Inventario guardado y catálogo de items |
| `piedra/` | La piedra mágica: poder, lectura (scouter), memoria del mundo |
| `combat/` | El duelo por turnos: reglas (`duel.gd`), su pantalla (`duel_ui.gd`), fichas de enemigo (`enemy_data.gd`, `enemy_move.gd`) y patrones (`enemy_ai.gd`) |
| `world/` | Niveles y zonas. `world/greybox/` es el nivel gris de la fase 1; `world/demo/` el cubo de la fase 0 |
| `ui/` | HUD y menús. `ui/safe_area/` respeta notch y barra de gestos |
| `core/` | Autoloads (globales). Hoy: `Sfx`, sonidos placeholder generados por código |
| `assets/` | Arte y audio compartido entre features |
| `tools/ci/` | Scripts que usa GitHub Actions |
| `tools/art/` | Generador de los sprites placeholder (`make_enemy_sprites.py`) |
| `tools/tests/` | Pruebas automáticas (p. ej. dedos simulados sobre los controles) |
| `docs/` | Guías y notas de diseño |

Cada feature junta su escena (`.tscn`), su script (`.gd`) y sus recursos, igual que un componente de React junta JSX, estilos y tests.

## Cómo se publica un release

Lo explica a detalle [`docs/flujo-de-releases.md`](docs/flujo-de-releases.md). En corto:

1. Cada avance llega como **pull request**. GitHub Actions corre un smoke test y construye un APK de prueba (queda como artifact del run).
2. Si el PR sube la versión en `project.godot` (`application/config/version`), al hacer merge a `main` se publica el **GitHub Release `vX.Y.Z`** con el APK firmado.

## Guía de Godot para devs web

Ver [`docs/godot-para-devs-web.md`](docs/godot-para-devs-web.md).
