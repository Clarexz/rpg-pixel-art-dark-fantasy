# Fase 5: primera zona (v0.6.x)

La fase 5 cambia el nivel gris por una zona de verdad, la **Hondonada de ceniza**. Caleb pidió hacerla en versiones chicas, una por paso del plan, para probar cada una antes de seguir:

| Versión | Paso | Estado |
|---|---|---|
| v0.6.1 | Separar el mundo de la zona | ✅ Publicada |
| v0.6.2 | Kit de construcción (bloques con texturas + navegación) | ✅ Publicada |
| v0.6.3 | La Hondonada en gris con los 6 enemigos comunes | ✅ Publicada |
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

## v0.6.2: kit de construcción y navegación

**Qué cambia para el jugador:** en el nivel gris, al sureste (a la derecha del inicio), hay una **ruina de ladrillo y roca** hecha con los bloques nuevos: paredes, un muro bajo, una caja y una rampa para subir a un escalón. Y los enemigos ya **rodean paredes y pilares** para alcanzarte en vez de quedarse pegados.

### El kit: bloques que se "pintan"

La zona se construirá con un **GridMap**: una cuadrícula 3D donde cada casilla mide 2x2x2 m y se llena con un bloque. Es como pintar un mapa de casillas (un tileset), pero en 3D.

| Id | Bloque | Textura | Forma |
|---|---|---|---|
| 0 | suelo_ceniza | ceniza | cubo de 2 m |
| 1 | suelo_escoria | escoria (con brasas) | cubo de 2 m |
| 2 | camino | empedrado | cubo de 2 m |
| 3 | pared_roca | roca | cubo de 2 m |
| 4 | pared_ladrillo | ladrillo viejo | cubo de 2 m |
| 5 | bloque_bajo | roca | medio cubo (1 m de alto): cobertura o escalón |
| 6 | caja | madera | caja de 1.6 x 1 x 1.2 m |
| 7 | rampa_baja | ceniza | rampa que sube de 0 a 1 m |
| 8 | rampa_alta | ceniza | rampa que sube de 1 a 2 m (maciza por debajo) |
| 9 | muro_bajo_ladrillo | ladrillo | medio cubo de ladrillo |

Las rampas suben hacia el "norte" del bloque; en el GridMap se giran para que suban a otro lado.

| Archivo | Qué es |
|---|---|
| `assets/tiles/*.png` | Las 6 texturas de 32x32 px. Se repiten sin cortes y cubren 2 m (un bloque) |
| `assets/tiles/tile_kit.tres` | El kit (MeshLibrary): forma, textura y colisión de cada bloque |
| `assets/tiles/materials/*.tres` | Un material por textura (pixelado nítido, continuo entre bloques vecinos) |
| `tools/art/make_tile_textures.py` | Genera las texturas de relleno |
| `tools/art/build_tile_kit.gd` | Arma el kit. Solo se vuelve a correr si se agregan formas nuevas |

**Para cambiar el look**, reemplaza el PNG en `assets/tiles/` con tu propio arte de 32x32 que se repita sin cortes. No hay que tocar nada más.

**Para pintar en Godot:** abre una zona, selecciona su nodo GridMap (en el nivel gris es `Level/Ruina`), y en el panel de abajo elige un bloque y haz clic en la vista 3D. Rueda del mouse con Ctrl/Cmd cambia de piso; las teclas A/S/D giran el bloque.

**No cambies los ids** de los bloques: el GridMap guarda el número, no el nombre. Bloques nuevos van al final.

### Navegación

- Cada zona puede tener un nodo `Navigation` (NavigationRegion3D). Al cargar la zona se calcula solo un **mapa de por dónde se puede caminar**, a partir de lo que esté en el grupo `navmesh_source` (en el nivel gris, todo `Level`).
- Los enemigos tienen un `NavigationAgent3D`: al patrullar y al perseguirte siguen ese mapa, así que rodean paredes. Si una zona no tiene mapa, van en línea recta como antes.
- Analogía web: es como un GPS. El mapa es Google Maps de la zona y el agente pide la ruta cada vez que te mueves.
- El mapa se arma "en directo" (`navigation/world/region_use_async_iterations=false` en `project.godot`): en segundo plano, en las pruebas de CI a veces nunca terminaba. Cuesta un instante al cargar la zona (≈0.1 s la Hondonada en la nube).

### Pruebas

- `zone_test` ahora también revisa que un Carroñero **rodee una pared** de 12 m para alcanzarte (sin navegación se queda pegado; se comprobó que la prueba falla en ese caso), que el kit tenga sus bloques con malla y colisión, y que el nivel gris tenga su ruina y su navegación.
- Las otras 5 pruebas siguen pasando.

### Qué probar en el celular

1. Camina a la ruina (sureste del inicio). ¿Las texturas se ven nítidas y pixeladas, sin parpadeos?
2. Sube la rampa al escalón de la ruina. ¿Se camina bien con el stick?
3. Deja que el Carroñero te vea y escóndete detrás de un pilar o de la ruina: ¿te rodea para alcanzarte?
4. ¿Sigue igual de fluido que v0.6.1?

## v0.6.3: la Hondonada de ceniza, en gris

**Qué cambia para el jugador:** el juego ya **empieza en la Hondonada de ceniza**, en el campamento del sur. El nivel gris sigue disponible en **Ajustes > Zona > Ir al campo de pruebas** (y de ahí "Volver a la Hondonada").

"En gris" quiere decir: el mapa, los caminos y los enemigos están en su lugar, con las texturas de relleno del kit. Todavía **no** hay hoguera que funcione, altar que se abra, rivales nuevos, niebla ni sonidos de ambiente (eso es v0.6.4 a v0.6.6).

### El mapa

Cada letra es una casilla de 2 x 2 m (72 x 92 m en total). Norte arriba; empiezas en la `P`.

```
####################################
####################################
#####........pppppppppp......#######
#####........pppAAAAppp......#######
#####........pppAAAAppp......#######
##...........pppppppppp......#######
##.......t...pppppppppp......#######
##..t....t...pppppppppp...........##
##......tt......rrrr....HHHHHHH...##
##...............==.....H.....H...##
##....t..t.......==...b.H.....H...##
##.....t.t..t....==...b.H..S..H...##
##...tt..........==.....H.....H...##
##....t...t.t....==.....H.....H.####
##.........t.....==.....HHH.HHH.####
##...t...........===========....####
##.t.t.......t...==............b####
##...............==....bb.......####
##...........t.c.==.............####
##...............==.o......#########
##.........t.....==........#########
##......=.=========........#MMMMM###
##......W........==..,,,,,,#MMMMM###
##...............==..,,,,G,#MMMMM###
##.t......t..t...==,,,,,,,,MMMMMM###
##.....t.........==,,,,,,,,MMMMMM###
##.t...t..t.t....=S..,,,,,,#MMMGM###
##............o..==..,,,,,,#MMMMM###
##......tt.......==........#MMMMM###
##....S.........c==........#########
##.........t.....==........#########
####...t.........==...............##
####........t....==...............##
####.........t...S=...............##
####.....t.......==c..............##
####.............==...............##
##...............==...............##
##...........c========c......#######
##...........==========......#######
######.......==========......#######
######.......==o=======......#######
######.......=====P====......#######
######.......c========c......#######
######.......................#######
####################################
####################################

  #  pared de roca (6 m)
  .  suelo de ceniza
  =  camino empedrado
  ,  suelo de escoria
  p  meseta del altar (1 m de alto)
  r  rampa a la meseta
  A  lugar del altar (muro bajo de ladrillo)
  H  torre en ruinas (8 m)
  b  muro bajo de ladrillo
  o  bloque bajo de roca
  c  caja / carreta
  t  árbol quemado (4 m)
  M  galería de la mina (con techo)
  P  inicio del jugador (campamento)
  S  Carroñero
  G  Gólem de escoria
  W  Lobo de ceniza (rival)
```

| Letra | Qué es |
|---|---|
| `#` | Pared de roca (6 m) |
| `.` `=` `,` | Suelo de ceniza, camino empedrado, suelo de escoria |
| `p` `r` `A` | Meseta del altar (1 m de alto), su rampa, y el lugar donde irá el altar |
| `H` | Torre en ruinas (8 m, se ve desde lejos) |
| `t` | Árbol quemado (4 m) |
| `M` | Galería de la mina (con techo) |
| `b` `o` `c` | Muro bajo, bloque bajo, caja o carreta (para cubrirte) |
| `P` | Inicio (campamento) |
| `S` `G` `W` | Carroñero (4), Gólem de escoria (2), Lobo de ceniza (rival) |

| Lugar | Enemigos |
|---|---|
| Campamento (sur) | Ninguno |
| Camino de escoria | 2 Carroñeros |
| Bosque quemado (oeste) | Lobo de ceniza + 1 Carroñero |
| Boca de la mina (este) | 1 Gólem afuera, 1 adentro de la galería |
| Torre en ruinas (noreste) | 1 Carroñero adentro |
| Meseta del altar (norte) | Ninguno |

**Tiempo:** del campamento al altar hay unos 77 m de camino, **≈17 s caminando** sin pelear. Es menos de lo que estimé en el plan (1-2 min para cruzar): los 5-10 minutos de la zona salen de las 7 peleas (1-2 min cada una) y de desviarse al bosque, la mina y la torre. Si se siente chica, se agranda en Godot.

### Cómo está hecha

- `world/zones/hondonada/hondonada.tscn`: un solo GridMap (`Terrain`) con los bloques del kit, los enemigos, la navegación y el `PlayerStart`. Su ficha: `hondonada_zone.tres` (id `hondonada`).
- La primera versión la generó `tools/art/build_hondonada.py` a partir del mapa de letras de arriba. **De aquí en adelante se edita en Godot** (pintando el GridMap); volver a correr el script borra esos cambios.
- Se agregó un bloque al kit: `10 tronco_quemado` (los árboles).
- Luz más cálida y cielo rojizo; la niebla y la luz de la hoguera llegan en v0.6.6.

### Pruebas

- `zone_test` ahora también revisa que, sin elegir zona, el juego empiece en la Hondonada; que tenga 4 Carroñeros, 2 Gólems y el Lobo; que **desde el campamento haya camino caminando hasta cada enemigo y hasta la meseta del altar**; y que el botón de Ajustes lleve al campo de pruebas y de regreso.
- Las pruebas de controles, duelo y combate siguen usando el campo de pruebas (nivel gris).

### Qué probar en el celular

1. Abre el juego: ¿empiezas en el campamento, mirando al norte por el camino?
2. Llega a la meseta del norte por la rampa. ¿Te orientas sin mapa (la torre se ve al noreste)?
3. Entra al bosque, a la mina y a la torre. ¿Algún lugar donde te atores, o un enemigo que se quede pegado?
4. Pelea con todos (son 7). ¿Cuánto tardaste en total? ¿Se siente chica o grande la zona?
5. Ajustes > Zona: ve al campo de pruebas y vuelve.
6. ¿Sigue fluido? (dentro de la mina y mirando a lo largo del camino es donde más se dibuja).
