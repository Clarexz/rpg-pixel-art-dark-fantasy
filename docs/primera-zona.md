# Fase 5: primera zona (v0.6.x)

La fase 5 cambia el nivel gris por una zona de verdad, la **Hondonada de ceniza**. Caleb pidió hacerla en versiones chicas, una por paso del plan, para probar cada una antes de seguir:

| Versión | Paso | Estado |
|---|---|---|
| v0.6.1 | Separar el mundo de la zona | ✅ Este documento |
| v0.6.2 | Kit de construcción (bloques con texturas + navegación) | Pendiente |
| v0.6.3 | La Hondonada en gris con los 6 enemigos comunes | Pendiente |
| v0.6.4 | Campamento y altar | Pendiente |
| v0.6.5 | Rivales nuevos (Penitente de hierro, Tejedora de hollín) | Pendiente |
| v0.6.6 | Ambiente (texturas finales, niebla, luz, sonidos) | Pendiente |
| v0.6.7 | Prueba anti-patente con 3 rivales y cierre de la fase | Pendiente |

Las reglas del combate no cambian en toda la fase.

## v0.6.1: el mundo y la zona, separados

**Qué cambia para el jugador: nada.** El juego se ve y se juega igual que v0.5.0. Lo que cambió es cómo está armado por dentro, para que la Hondonada (y después otras zonas) se puedan cargar sin tocar al jugador, el HUD ni el duelo.

Antes, `world/greybox/greybox.tscn` tenía todo junto: el terreno, los enemigos, el jugador, el HUD y el duelo. Ahora está partido en dos:

| Pieza | Archivo | Qué tiene |
|---|---|---|
| **Mundo** | `world/world.tscn` + `world/world.gd` | Lo que siempre está: jugador, HUD, controles, Ajustes, duelo, transición. Y una ranura vacía (`ZoneSlot`) |
| **Zona** | `world/zones/greybox/greybox.tscn` | El terreno, la luz, el cielo, los muñecos y los enemigos. Un `PlayerStart` que dice dónde apareces |
| **Ficha de zona** | `world/zones/greybox/greybox_zone.tres` (`ZoneData`) | El id de la zona (`greybox`) y su nombre ("Campo de pruebas") |

Analogía web: `world.tscn` es el **layout** de la app (barra, menú) y cada zona es una **página** que se monta adentro. Cambiar de zona es navegar a otra página: el layout no se vuelve a montar.

### Cómo funciona

- Al arrancar, `World` carga su `start_zone` (hoy el nivel gris) con `load_zone()`.
- `load_zone(escena)` quita la zona anterior, monta la nueva, te pone en su `PlayerStart`, conecta a sus enemigos y le dice al duelo en qué zona estás.
- El duelo guarda esa zona en cada `Encounter`, así la piedra sabe dónde ganaste tu fama (antes estaba fija en `greybox`).
- La piedra solo vibra por los enemigos de la zona cargada.
- No se puede cambiar de zona a media pelea.

Esto deja lista la puerta para el **streaming de zonas** (cargar la siguiente mientras caminas), pero no se implementa todavía.

### Cómo hacer una zona nueva (para después)

1. Crea una escena cuyo nodo raíz use `world/zones/zone.gd`.
2. En el Inspector, ponle una ficha `ZoneData` con un id que no cambie nunca (la fama se guarda con ese id).
3. Agrega un `Marker3D` llamado `PlayerStart`.
4. Mete a los enemigos (instancias de `enemies/enemy.tscn`) donde quieras.

### Pruebas

- Nueva: `tools/tests/zone_test` (corre en CI). Revisa que la zona inicial se cargue en la ranura, que apareces en `PlayerStart`, que los enemigos queden conectados, que cambiar a otra zona libere la anterior y sus enemigos, que un duelo en la zona nueva se registre con su id, y que no se cambie de zona durante un duelo.
- Las 5 pruebas de antes (`controls`, `duel`, `rivals`, `pixel`, `combat`) pasan sin cambiar lo que revisan; solo ahora cargan `world.tscn`.

### Qué probar en el celular

1. Abre el juego: debe verse y jugarse **igual que v0.5.0** (mismo nivel gris, mismos enemigos).
2. Pelea con cada enemigo y abre Ajustes > Prueba de rendimiento: al terminar debe volver al nivel gris.
3. Si algo se ve distinto o falla, eso es un error de esta versión.
