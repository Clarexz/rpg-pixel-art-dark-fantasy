# v0.5.0: combate real (fase 3)

El duelo de v0.2.0 contra un cubo ahora es contra **enemigos de verdad**: dibujados en pixel art, con vida, movimientos propios y un patrón que se puede aprender. Las reglas del duelo **no cambiaron**: por turnos, a una mano, menú Cuerpo a cuerpo / Hechizos / Items / Huir, cuadrícula 2x3 (abajo atacas gastando PA, arriba bloqueas, el bloqueo perfecto devuelve PA) y hechizos como canciones. Eso sigue explicado en [prototipo-una-mano.md](prototipo-una-mano.md).

Decisiones de Caleb para esta fase: sprites hechos por Claude (de relleno, reemplazables), siempre 1 contra 1, morir no quita nada por ahora, y de un rival siempre se puede huir.

## Los enemigos

| Enemigo | Tipo | Vida | Cómo pelea | Débil a | Suelta |
|---|---|---|---|---|---|
| **Carroñero** | Común (sin memoria) | 60 | Rápido. Tajo, Doble tajo (combo de 2). Con poca vida: Frenesí (combo de 3) | Fuego | Poción 50%, Éter 25% |
| **Gólem de escoria** | Común (sin memoria) | 110 | Lento y pesado. Puñetazo, y **Aplastar** (cargado, 32 de daño) | Trueno | Éter 40%, Bomba 40% |
| **Lobo de ceniza** | **Rival** (te recuerda) | 120 | Zarpazo, **Amago** (finta), Dentellada doble (combo), **Aullido de brasas** (cargado) | Fuego | Poción 70%, Bomba 30% |

Están en el nivel gris: el Carroñero a la derecha, el Gólem a la izquierda junto a la rampa y el Lobo al fondo.

### En el mundo

- **Patrullan** cerca de su lugar.
- Si te acercas a menos de ~6.5 m **te ven**: se llena un "!" rojo y empiezan a **perseguirte**. El Carroñero es rápido; del Gólem te puedes alejar caminando.
- Si te alcanza, **empieza él** (emboscada). Si le pegas con ATACAR antes, **empiezas tú** con +2 PA y 10 de daño (golpe primero). Esto funciona incluso mientras te persigue.
- Si huyes, no te persigue por 6 segundos. Al vencerlo desaparece y vuelve a los 15 s (el lobo a los 20 s) para que puedas volver a probar.
- La piedra vibra cuando hay cualquier enemigo cerca.

## Los movimientos del enemigo (todos se bloquean con la fila de arriba)

El enemigo usa sus movimientos **en orden, siguiendo su patrón**, y cambia a otro patrón cuando le queda menos de la mitad de vida. No es azar: después de unas peleas sabrás qué viene. Lo que sí es al azar es el lado de cada golpe.

| Movimiento | Cómo se avisa | Qué hacer |
|---|---|---|
| **Simple** | El sprite se pone en pose de "preparar" inclinado hacia un lado; flecha roja con aro. | Bloquear de ese lado cuando el aro llega a lo dorado. |
| **Combo** | Antes de empezar se ven los lados **numerados 1, 2, 3**; luego los golpes llegan seguidos y más rápidos. | Bloquear cada uno en orden. |
| **Finta** | Aro **morado con "?"**. A la mitad del aviso **cambia de lado** (el aro se pone rojo). | No tocar hasta que cambie. Si bloqueas antes, te comes la finta ("¡Era una finta!"). |
| **Cargado** | Un turno se prepara: brilla, se infla, y arriba dice "⚡ Cargando ...". No pega ese turno. Al siguiente suelta un golpe muy fuerte. | **Trueno** lo corta (y lo aturde). **Égida** reduce el daño a la mitad. O bloquearlo perfecto. |

Un rival que ya te conoce además puede "atacar más seguido" (un golpe extra al final de su turno) y "cambiar el ritmo" (avisos más rápidos o más lentos), igual que en v0.3.0.

## Items

- Tu inventario **se guarda en el celular** (`user://inventory.tres`). Empiezas con 2 Pociones, 1 Éter y 1 Bomba de ceniza. Tope: 9 de cada uno.
- **Poción** +30 PV · **Éter** +6 PM · **Bomba de ceniza** 18 de daño fijo (no la bloquea ni la resiste).
- Usar un item gasta tu turno.
- Al ganar, el enemigo puede soltar items (tabla de arriba). Lo ves como "Botín: ..." al final del duelo.

## Huir

La probabilidad depende de lo que lee tu piedra del enemigo, y el botón Huir te lo dice:

| La piedra lo lee | Botón | Probabilidad |
|---|---|---|
| Más débil que tú | Huir (fácil) | 85% |
| Parecido a ti | Huir (parejo) | 65% |
| Más fuerte que tú | Huir (difícil) | 40% |
| La lectura se rompe | Huir (muy difícil) | 25% |

Si fallas, el enemigo ataca. Un rival recuerda que huiste y te lo echa en cara (eso ya existía).

## Ganar y perder

- **Ganar:** XP para tu piedra. Si es un **rival** y es la primera vez, además absorbes un fragmento de su piedra. Los enemigos comunes solo dan XP.
- **Perder:** vuelves al inicio del nivel con la vida llena. No pierdes items ni XP (se decide en la fase 6).

## La patente (por qué esto sigue lejos)

Nada nuevo se acerca al claim 1 de US 10,926,179 (ver [rivales-y-piedra.md](rivales-y-piedra.md)). No es asesoría legal.

- Los enemigos comunes **no tienen memoria ni rango**: `greybox.gd` solo pide memoria si `enemy.is_rival()`. La prueba `combat_test` falla si el Carroñero termina con memoria.
- El patrón de un enemigo (`EnemyAI.choose`) solo recibe **su propia ficha**. Las tácticas de un rival siguen saliendo solo de su ficha y su memoria (`RivalTactics.plan(RivalData, RivalMemory)`), y sus pruebas siguen en CI.
- Lo que pasa con un enemigo no cambia a ningún otro. Las piedras solo cambian de manos a través de ti.

## En la pantalla del duelo

- La vista baja un poco (12°) para ver al enemigo de cuerpo entero, y el arma se hace a un lado para no tapar su pose. La **pose del sprite** es el aviso principal; la flecha queda de apoyo.
- El botón Huir dice qué tan fácil es huir. Debajo de la vida del enemigo aparece "⚡ Cargando ..." cuando prepara un golpe fuerte.

## Qué probar en el celular

1. Camina hacia cada enemigo: ¿se entiende cuándo te vio (el "!") y que te persigue? ¿Logras pegarle primero?
2. ¿Distingues cada movimiento **por la pose del sprite** antes de mirar la flecha?
3. **Finta del lobo:** ¿se entiende el aro morado con "?"? ¿Es justa o frustrante?
4. **Golpe cargado del gólem:** ¿se entiende que hay que usar Trueno o Égida?
5. ¿Una pelea dura 1-2 minutos y se siente justa? ¿Algún enemigo es demasiado fácil o difícil?
6. Gasta items, gana botín, cierra la app y vuelve a abrirla: ¿siguen ahí?
7. Huye del Carroñero (fácil) y del Lobo (difícil).
8. Pelea 3 veces con el Lobo atacando del mismo lado: al cuarto duelo te lo dice y lo cubre.

## Dónde está el código

| Archivo | Qué hace |
|---|---|
| `combat/enemy_data.gd` | Ficha de un enemigo: vida, poder, sprite, movimientos, patrón, botín (como las props de un componente) |
| `combat/enemy_move.gd` | Un movimiento: tipo (simple, combo, finta, cargado), daño, golpes y tiempo de aviso |
| `combat/enemy_ai.gd` | Qué movimiento toca según el patrón (función pura) |
| `combat/duel.gd` | Reglas del duelo; números arriba del archivo (huir, finta, combos) |
| `combat/telegraph_view.gd` | Flecha y aro; finta en morado; lados numerados del combo |
| `enemies/enemy.gd`, `enemy.tscn` | El enemigo en el mundo: patrulla, te ve, te persigue, poses del sprite |
| `enemies/data/*.tres`, `rivals/data/ash_wolf.tres` | Las fichas (se editan en el Inspector de Godot) |
| `enemies/sprites/*.png` | Tiras de 6 cuadros de 48x48: quieto A, quieto B, preparando, golpeando, herido, derrotado |
| `tools/art/make_enemy_sprites.py` | Genera esos sprites. Para usar arte propio, reemplaza el PNG respetando tamaño y orden de cuadros |
| `items/inventory.gd` | Inventario guardado, catálogo de items (números ajustables) y botín |
| `tools/tests/combat_test.gd` | Prueba automática de todo lo de arriba (corre en CI) |

## Notas de lo probado en la nube

- `combat_test` (nueva) prueba: fichas y sprites, patrones, inventario y botín, huir según la piedra, que el Carroñero te vea, te persiga y te alcance, un duelo completo contra él (combo de 2, bomba, victoria, botín, sin memoria), el Gólem cargando (Trueno lo corta; si no, pega 32), y la finta del Lobo (cambia de lado y se bloquea perfecto).
- Las pruebas de antes (`controls_test`, `duel_test` ahora contra el Lobo, `rivals_test`, `pixel_test`) siguen pasando.
- _(pendiente: notas de Caleb en su celular)_
