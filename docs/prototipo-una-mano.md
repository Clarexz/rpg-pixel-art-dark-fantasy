# v0.2.0: prototipo a una mano (exploración + duelo)

> **Desde v0.5.0** el cubo fue reemplazado por enemigos de verdad (Carroñero, Gólem de escoria y el rival Lobo de ceniza), con movimientos propios, items guardados y huir según la piedra. Las reglas de este documento (menú, cuadrícula 2x3, bloqueo perfecto, canciones) siguen igual. Lo nuevo está en [combate-real.md](combate-real.md).

Objetivo: comprobar si el juego **se puede jugar con un solo pulgar en vertical**, y si el duelo por turnos con la cuadrícula de botones se siente bien. Todo es placeholder: un rival (un cubo), sonidos generados por código, sin arte.

## Cómo se juega

### Explorar (un pulgar)

- **Mover:** pon el pulgar en cualquier lugar de la mitad de abajo y arrastra. Hay dos modos para comparar (Ajustes → *Modo de movimiento*):
  - **Una mano: libre** ("stick de tanque", el default): arriba/abajo = avanzar/retroceder, a los lados = **girar**. Así un solo dedo camina y mira. Empujar hasta el borde hacia adelante = correr.
  - **Una mano: por casillas**: cada empujón es un paso de una casilla (2 m) o un giro de 90°, como los dungeon crawlers clásicos. Mantener empujado repite el paso.
  - **Dos pulgares (v0.1)**: los controles anteriores, por si quieres comparar.
- **ATACAR** y **PIEDRA** quedan del lado de tu mano. *Modo zurdo* los pasa a la izquierda (también en el duelo).
- La vista se nivela sola (con un pulgar no hay cómo mirar arriba/abajo). ATACAR tiene una pequeña ayuda de puntería: si el rival está enfrente y cerca, le pegas aunque la mira no esté exacta.

### Encontrar al rival

- Cuando hay un rival a menos de 10 m, **la piedra vibra**: pulsos más seguidos y fuertes entre más cerca (y un aviso arriba).
- **Golpe primero:** si le pegas con ATACAR antes de que te note, empiezas tú, le quitas 10 PV y ganas +2 PA.
- **Emboscada:** si te quedas cerca sin atacar, se le llena un "!" rojo y te ataca él primero.
- **Transición:** la pantalla se pixela en el lugar (sin pantalla de carga), el cubo queda enfrente y te saluda con algo que recuerda de ti, p. ej. *"La última vez huiste."*

### El duelo (por turnos)

Tu turno empieza con un menú de 4 botones grandes, pegados a la orilla de tu mano:

| Opción | Qué hace |
|---|---|
| **Cuerpo a cuerpo** | Aparece la cuadrícula 2x3. La fila de **abajo** ataca por izquierda/centro/derecha. Cada golpe cuesta **2 PA**; puedes encadenar golpes mientras te alcancen. El cubo cubre un lado: si le pegas ahí, lo bloquea (casi no le haces daño). "Terminar turno" cuando quieras. |
| **Hechizos** | Eliges uno de 4 y tocas su **canción** (3 o 4 casillas de la misma cuadrícula, como la ocarina). Cada casilla suena con su nota. Si te equivocas o tardas, se deshace y pierdes la mitad de los PM. Si la tocas con **ritmo parejo**, sale x1.5. |
| **Items** | Poción (+30 PV, 2 usos) o Éter (+6 PM, 1 uso). Gasta tu turno. |
| **Huir** | 65% de probabilidad. Si fallas, el cubo ataca. |

Hechizos equipados (casillas: arriba = 1 2 3, abajo = 4 5 6, de izquierda a derecha):

| Hechizo | PM | Canción | Efecto |
|---|---|---|---|
| Fuego | 4 | abajo-izq, arriba-centro, abajo-der | 20 de daño (ignora el bloqueo) |
| Curar | 4 | abajo-centro, arriba-centro, abajo-centro | +25 PV |
| Égida | 3 | arriba-izq, arriba-der, arriba-centro | El siguiente turno del cubo te hace la mitad de daño |
| Trueno | 6 | abajo-der, arriba-der, arriba-izq, abajo-izq | 12 de daño y el cubo pierde su turno |

**Turno del cubo:** aparece una flecha con un aro rojo que se encoge del lado por donde viene el golpe. Toca **Bloquear** (fila de arriba) del mismo lado:

- **Bloqueo perfecto:** justo cuando el aro llega al círculo dorado (últimos 0.25 s). No recibes daño y **recuperas 2 PA**.
- **Bloqueo normal:** lado correcto pero antes de tiempo. Recibes 35% del daño.
- **Fallo:** lado equivocado o no bloqueas. Daño completo.
- Solo cuenta tu **primer** toque (no sirve machacar).
- Entre menos vida tiene el cubo, más golpes seguidos hace (1 a 3).

PA: empiezas con 4, +3 cada turno (máx. 10). PM: empiezas con 6, +2 cada turno (máx. 12).

### La memoria del cubo

Se guarda en el celular (`user://rival_memory.tres`): cuántos duelos llevan, cómo terminó el último y por qué lado sueles atacar. Con eso:

- Te saluda distinto: primera vez, si huiste, si le ganaste o si te ganó.
- **Desde el tercer duelo cubre tu lado favorito** el 70% de las veces, y te lo dice ("Siempre atacas por la izquierda..."). Toca variar.

Para el prototipo, el cubo reaparece a los 4 segundos de vencerlo, y si pierdes vuelves al inicio del nivel con la vida llena.

### Sensación de impacto

- **Vibración:** distinta para golpe, bloqueo, perfecto, recibir daño, notas de hechizo y la piedra.
- **Hitstop:** el juego se congela unos milisegundos al conectar un golpe (más largo en el bloqueo perfecto). Es lo que hace que un golpe se sienta pesado.
- **Sonido:** placeholders generados por código en `core/sfx.gd` (golpe, choque de metal, notas tipo ocarina, etc.).
- Sacudida de cámara y destellos de color.

## Qué probar en el celular

1. **Libre vs. por casillas:** ¿cuál se siente mejor con una mano para explorar? ¿El giro es muy rápido o lento? (Ajustes → *Velocidad de giro*).
2. ¿Llegas cómodo con el pulgar a **todos** los botones del duelo sin cambiar el agarre? ¿Y en modo zurdo?
3. **Bloqueo perfecto:** ¿la ventana es muy fácil o muy difícil? ¿Se entiende el aro?
4. **Canciones:** ¿se memorizan rápido? Prueba apagar *Mostrar las notas de los hechizos* después de unas peleas.
5. ¿El golpe primero vs. la emboscada se entiende sin explicación?
6. Pelea 3 veces atacando siempre del mismo lado: ¿se nota que el cubo te "leyó"?
7. ¿La vibración ayuda o cansa?

## Dónde está el código

| Archivo | Qué hace |
|---|---|
| `ui/touch_controls/one_hand_controls.gd` | Stick de un pulgar (libre y por casillas) y botones del lado de la mano |
| `player/player.gd` | Giro de tanque, pasos por casillas, animaciones del duelo |
| `rivals/test_cube/rival_cube.gd` | El cubo: te nota, te embosca, animaciones |
| `rivals/` y `piedra/` | Memoria de rivales, tácticas, saludos y la piedra: ver [rivales-y-piedra.md](rivales-y-piedra.md) |
| `combat/duel.gd` | **Reglas del duelo** (números arriba del archivo, fáciles de ajustar) |
| `combat/duel_ui.gd` | Pantalla del duelo, construida por código |
| `combat/telegraph_view.gd`, `combat/song_display.gd` | La flecha con aro y la "partitura" de los hechizos |
| `ui/transitions/` | La transición pixelada |
| `core/sfx.gd` | Sonidos placeholder |
| `tools/tests/duel_test.gd` | Prueba automática con dedos simulados (corre en CI) |

## Notas de lo probado en la nube

- La prueba automática juega un duelo completo con toques reales: stick de una mano, pasos por casillas, golpe primero, golpes, bloqueo perfecto, hechizo con su canción, recibir daño, huir y que el cubo lo recuerde.
- Encontrado y corregido: cuando el menú cambia a la cuadrícula bajo el pulgar, el botón nuevo "recibía" el mismo toque. Ahora los botones ignoran toques 0.15 s después de cambiar.
- Pendiente: el arma placeholder tapa parte de la vista en vertical (se rediseña con el pixel art). El modo por casillas no sube escaleras ni rampas.
- _(pendiente: notas de Caleb en su celular)_
