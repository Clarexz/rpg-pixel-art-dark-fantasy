# Rivales con memoria y la piedra (Fase 4, v0.3.0)

Este documento explica cómo funcionan los rivales que te recuerdan y la piedra mágica, por qué se diseñaron así, y cómo se mantienen lejos de la patente del sistema Nemesis de Warner Bros. Es solo lógica: no agrega arte ni escenas nuevas al mundo.

> **No es asesoría legal.** Es un análisis de diseño para bajar el riesgo. Antes de un lanzamiento comercial hay que revisarlo con un abogado de patentes (y revisar también la patente de continuación).

## La idea en una frase

Cada rival es **independiente** y solo aprende de **lo que vivió contigo**. Tu piedra aprende de **ti**. Nada de lo que pase con un rival cambia cómo pelea otro.

## Las piezas

| Archivo | Qué es | Analogía web |
|---|---|---|
| `rivals/rival_data.gd` + `rivals/data/*.tres` | Lo que un rival **es**: nombre, vida, poder, debilidad, astucia, orgullo, frases | Un registro fijo en una tabla `rivals` |
| `rivals/encounter.gd` | El resumen de **un** duelo: con quién, resultado, tus golpes por lado, hechizos, bloqueos | El payload de un evento `duel_finished` |
| `rivals/rival_memory.gd` | Lo que **un** rival recuerda de ti (contadores) | Una fila por rival en `rival_memories` |
| `rivals/rival_registry.gd` | Un cajón con una memoria por id, guardado en `user://rivals.tres` | `Map<rivalId, Memory>` en localStorage |
| `rivals/rival_tactics.gd` | **Función pura** `plan(rival, su_memoria) → tácticas` | Un selector de Redux |
| `rivals/rival_dialogue.gd` | Lo que dice al empezar y al caer (solo texto) | Un helper de copy |
| `piedra/player_record.gd` | Lo que tu piedra sabe de **ti**: XP, nivel, estilo, fama por zona | El perfil del usuario |
| `piedra/power_reading.gd` | La lectura de poder (el "scouter") | Un formatter que depende del nivel |
| `piedra/piedra.gd` (autoload `Piedra`) | Guarda tu `PlayerRecord` y reenvía `reputation_changed` / `level_changed` | Un store global |
| `rivals/sim/rival_sim.gd` + `tools/sim/rival_sim.tscn` | Simulación de 10 duelos en texto | Un script de seed + reporte |
| `tools/tests/rivals_test.gd` | 69 comprobaciones que corren en CI | Un archivo de Jest |

El flujo de datos es de una sola vía:

```
Duelo ──(Encounter)──► memoria de ESE rival
                  └──► tu PlayerRecord (piedra)

Al empezar el siguiente duelo con ese rival:
RivalData + SU memoria ──plan()──► tácticas (cómo pelea)
```

## Qué aprende un rival de ti

Todo sale de su propia memoria. Con astucia 1 (el cubo) empieza a usarlo desde su **4.º duelo** (después de 3); con astucia 1.5 (el lobo), desde su **3.º**.

| Si tú... | El rival... | Dónde |
|---|---|---|
| Atacas mucho por un lado (≥40 % de tus golpes) | Cubre ese lado el 70 % de las veces y te lo dice | `RivalTactics.guard_side` |
| Le lanzas el mismo hechizo 3+ veces | Lo resiste (daño x0.65). Si era su debilidad, deja de serlo | `resists` |
| Lo vences con un hechizo | Vuelve con esa **cicatriz**, la menciona y la resiste | `RivalMemory.scars` |
| Bloqueas perfecto 40 %+ de sus golpes | Cambia el ritmo: avisos más cortos y más largos | `windup` |
| Pierdes contra él 2+ veces | Se envalentona: un golpe más por turno, y su poder sube +10 por cada vez que te venció | `extra_strikes`, `rival_power()` |
| Huyes | Te lo echa en cara ("Ya huiste 3 veces.") | `RivalDialogue` |

La debilidad propia del rival (Trueno para el cubo, Fuego para el lobo) hace x1.3 de daño. En el duelo verás "¡Lo resiste!" o "¡Su debilidad!".

## La piedra

1. **Fuente de poder.** Ganas XP de piedra al pelear: victoria +20, derrota +5, huida +2, cada bloqueo perfecto +2. La **primera** vez que vences a un rival absorbes un fragmento de su piedra (+20 extra). Niveles en 0 / 30 / 80 / 160 XP. Tu poder = 100 + 25 por nivel.
2. **Lector (scouter).** Al empezar el duelo la piedra lee al rival. Precisión según tu nivel:
   - Nivel 1: "más fuerte / parecido / más débil".
   - Nivel 2: número aproximado (de 25 en 25).
   - Nivel 3: de 10 en 10 y su debilidad.
   - Nivel 4: número exacto.
   Si el rival es demasiado fuerte para tu piedra, la lectura **se rompe** ("la piedra se agrieta...").
3. **Memoria del mundo.** Registra tu estilo (lado favorito, hechizo favorito, si huyes) y tu **fama por zona** (victoria +3, derrota −1, huida −2). Cada cambio emite `reputation_changed(zona, valor)`. La fama da un título ("el retador del que hablan", "el que siempre huye").

## La patente (US 10,926,179) y por qué esto queda lejos

El claim 1 pide **todos** estos elementos a la vez. Así se compara cada uno con nuestro diseño:

| Elemento del claim 1 | ¿Lo tenemos? | Por qué |
|---|---|---|
| 1. NPCs en una facción con jerarquía | **No** | `RivalData` no tiene facción, rango, jefe ni orden. El registro es un diccionario plano por id. |
| 2. NPCs se comportan según su estatus en la jerarquía | **No** | No hay estatus. Las tácticas salen de la astucia del rival y de su memoria de ti. |
| 3. Un encuentro con el jugador cambia el estatus del NPC | **No (en ese sentido)** | Un rival sí cambia por pelear contigo (aprende, se envalentona), pero eso es su memoria de ti, no un puesto en una jerarquía. |
| 4. Ese cambio altera los parámetros de control de un **segundo** NPC | **No** | `RivalTactics.plan()` solo recibe `(RivalData, RivalMemory)` de ese rival. `RivalMemory.record()` rechaza duelos de otro rival. Hay pruebas automáticas para las dos cosas. |
| 5. Controlar al segundo NPC con esos parámetros | **No** | Consecuencia del punto 4. |

Faltan los elementos 1, 2, 4 y 5. Para infringir hay que cumplir todos, y la **doctrina de equivalentes** (otro camino que logra sustancialmente lo mismo) se cubre con la regla de oro: los rivales nunca se reconfiguran entre ellos. Tampoco usamos a la piedra como "puente" para pasar cambios de un rival a otro.

### Guardias en el código (pruebas que fallan si alguien se acerca a la línea)

- `test_isolation_between_rivals`: hace 8 duelos con el cubo y comprueba que la memoria, las tácticas, el saludo y el poder del lobo quedan **idénticos**.
- `test_plan_only_takes_rival_and_its_memory`: si alguien le agrega a `plan()` un parámetro como "otros rivales", "facción" o el registro, la prueba falla.
- `RivalMemory.record()` ignora (con error) un duelo de otro rival.

### Lo que más se acerca a la línea (aviso)

- **La fama del jugador en los saludos.** Un rival nuevo puede decir "Así que tú eres el retador del que hablan", y esa fama sube por vencer a *otros* rivales. Es reputación **del jugador** que el rival lee (permitido en las reglas de `contexto-juego-rivales.md`), y **solo cambia texto**, nunca tácticas, poder ni comportamiento. Aun así es el punto más cercano, por eso está aislado en `RivalDialogue` y se apaga con `USE_FAME = false`.
- **El rival que se hace fuerte al vencerte.** Es el mismo rival cambiando por su propio duelo contigo (no un segundo NPC), y no hay jerarquía. Riesgo bajo.

### Qué NO hacer en fases futuras

- Facciones con rangos, capitanes, jefes o ascensos.
- Que vencer/perder contra el rival A haga más fuerte, más listo o de mayor rango al rival B.
- Que los rivales se quiten piedras entre ellos o "hereden" la memoria de otro (las piedras solo cambian de manos a través de ti).
- Usar la fama del jugador para cambiar tácticas, stats o comportamiento de combate.

## Cómo se conecta al duelo (cambios mínimos)

> **Desde v0.5.0** el cubo ya no está en el nivel: el rival jugable es el **Lobo de ceniza** y el cubo solo vive en las pruebas y la simulación. Los enemigos comunes (Carroñero, Gólem) no tienen memoria. Ver [combate-real.md](combate-real.md).

- `combat/duel.gd`: al empezar calcula `RivalTactics.plan(...)`; la guardia, el tiempo de aviso, los golpes por turno y el daño de hechizos salen de ahí. Va llenando un `Encounter` y al final lo entrega a la memoria del rival y a la piedra (`_save_encounter()`).
- Al empezar el duelo verás la **lectura de la piedra** arriba de las instrucciones, y el saludo del rival según lo que recuerda.
- (v0.3.0) El cubo tenía `data: RivalData`. Desde v0.5.0 todo enemigo en el mundo es `enemies/enemy.gd` con su ficha (`EnemyData` o `RivalData`).
- `world/greybox/greybox.gd` usa `RivalRegistry` en vez de una sola memoria. El guardado viejo (`user://rival_memory.tres`) ya no se usa: el cubo te "olvida" una vez al actualizar.

## Simulación de 10 duelos

Corre `tools/sim/rival_sim.tscn` en el editor (F6) o mira el log de la prueba en CI. Resultado actual (resumido):

| # | Rival | Lo que aprendió | Resultado |
|---|---|---|---|
| 1 | Cubo | nada (lo conoces) | huyes |
| 2 | Lobo | nada | pierdes |
| 3 | Cubo | nada ("La última vez huiste.") | pierdes |
| 4 | Lobo | nada | pierdes |
| 5 | Cubo | nada | **ganas** y absorbes fragmento |
| 6 | Lobo | cubre la izquierda, ataca más seguido | huyes |
| 7 | Cubo | cubre la izquierda, resiste Fuego, cambia el ritmo | ganas |
| 8 | Lobo | cubre la izquierda, ataca más seguido | ganas |
| 9 | Cubo | igual que antes ("2 veces me has tumbado.") | ganas |
| 10 | Lobo | además resiste Fuego (su cicatriz) | ganas |

Cada rival recuerda solo sus 5 duelos, el lobo (más astuto) aprende un duelo antes que el cubo, y la lectura de la piedra se vuelve más precisa al subir de nivel.

## Qué probar en el celular

1. Pelea con el Lobo de ceniza (desde v0.5.0; antes el cubo) y fíjate en la línea "Piedra: ..." al empezar.
2. Ataca casi siempre por un lado durante 3 duelos: en el 4.º te lo dice y lo cubre.
3. Usa Fuego en varios duelos: después dirá "Tu Fuego ya no me asusta" y verás "¡Lo resiste!".
4. Remátalo con Trueno (su debilidad): verás "¡Su debilidad!" y luego volverá con la cicatriz.

## Números para ajustar

Todos están como constantes arriba de cada archivo: `RivalTactics` (cuándo y cuánto se adapta), `PlayerRecord` (XP, niveles, fama), `PowerReading` (precisión y cuándo se rompe la lectura).
