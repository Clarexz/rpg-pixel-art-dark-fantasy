# Guía para Claude en este repo

Juego de celular (Android) en Godot 4.7.2: RPG pixel art de fantasía oscura, en primera persona, a una mano, con duelos por turnos y rivales con memoria + piedra mágica.

## Quién hace qué (modelos)

| Rol | Modelo | Qué hace |
|---|---|---|
| Coordinador y los 6 hilos persistentes | Opus | Orquestan, diseñan, planean la arquitectura y **revisan** todo lo que escriben los subagentes. |
| `programador` (`.claude/agents/programador.md`) | Sonnet | Implementa en GDScript un plan ya aprobado, escribe pruebas y arregla el CI. |
| `tareas-simples` (`.claude/agents/tareas-simples.md`) | Haiku | Búsquedas en el código, renombres, docs y `.md`, cambios mecánicos pequeños. |

Reglas:
- Los hilos Opus **no delegan el diseño**: el plan lo hace Opus, y solo después se le pasa a `programador` el código y a `tareas-simples` lo trivial.
- `tareas-simples` **nunca** toca la lógica de `combat/`, `rivals/` ni `piedra/` (riesgo de patente del sistema Nemesis; ver `contexto-juego-rivales.md`, secciones 4 y 5).
- Todo lo que escriban Sonnet o Haiku lo revisa el hilo Opus que los llamó y **pasa el CI** (`.github/workflows/android.yml`) antes del merge.
- Para ahorrar uso: elige el agente más barato que pueda hacer la tarea bien; si dudas entre Haiku y Sonnet, usa Sonnet.

## Reglas de trabajo de Caleb

- **Plan primero:** antes de cada trabajo, darle a Caleb el plan y esperar su OK.
- **Versiones (desde 2026-11-26, serie nueva desde v0.1.0):**
  - **Build de prueba** por área: pre-release `vX.Y.Z-<area>.N`. En la rama del área, `config/version` de `project.godot` = la siguiente versión oficial; se publica corriendo el workflow `Android build` a mano en esa rama (`workflow_dispatch`). No quema números de versión.
  - **Release oficial** desde `main`: `0.X.0` por hito, `0.X.Y` por arreglos. El PR que sube la versión agrega `docs/notas/vX.Y.Z.md` con notas agrupadas por área. El push a main publica el Release.
  - Los releases del prototipo (v0.0.1 a v0.6.3) están archivados como `proto-v0.x.y`. Detalle en `docs/flujo-de-releases.md`.
- **Observaciones:** todo lo que Caleb reporte al probar se anota en `/mnt/project-files/Observaciones.md`, y no se trabaja hasta que él lo diga.
- **Roadmap:** actualizar `/mnt/project-files/roadmap-y-prompts.md` (y `contexto-juego-rivales.md` si aplica) cada vez que cambien mecánicas u organización.
- **Memoria por hilo:** cada hilo persistente lleva su memoria y plan en `/mnt/project-files/memoria-hilos/<area>.md`; un hilo nuevo de un área la lee primero.
- **Ramas por área, sin prefijo:** `mecanicas`, `mundo`, `lore`, `enemigos`, `sprites`, `ui-ux`. El merge a main lo hace Claude cuando pasa el CI.
- Caleb habla español y es nuevo en gamedev: explica en español claro, sin jerga.

## Datos técnicos

- Render 480 px de alto escalado nítido, renderer Mobile. Celular de prueba: Galaxy A56.
- Pruebas: escenas `tools/tests/*_test.tscn`, se corren con `godot --headless --path . res://tools/tests/<x>_test.tscn`.
- Docs de cada fase en `docs/`; flujo de releases en `docs/flujo-de-releases.md`.
