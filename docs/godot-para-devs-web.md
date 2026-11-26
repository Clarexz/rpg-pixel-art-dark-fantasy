# Godot para devs web

Una traducción de los conceptos de Godot a lo que ya conoces de React, el DOM y Node. Crece con cada fase.

## Nodos y escenas

| Godot | Web | Nota |
|---|---|---|
| **Nodo** | Elemento del DOM / componente | Cada cosa del juego es un nodo: una cámara, una luz, un label, un cubo. |
| **Árbol de escena** | El DOM | Los nodos forman un árbol padre-hijo. Mover al padre mueve a los hijos. |
| **Escena** (`.tscn`) | Componente React reutilizable | Un sub-árbol guardado en un archivo. Se instancia muchas veces (cada enemigo es una instancia de `enemy.tscn`). |
| **Script** (`.gd`) | La lógica del componente | Se "pega" a un nodo y extiende su comportamiento (`extends MeshInstance3D`). |
| `@export var` | Props | Variables editables desde el Inspector del editor, sin tocar código. |
| **Resource** (`.tres`) | Un JSON tipado / objeto de config | Datos puros: stats de un rival, la memoria de un rival, ajustes de sensibilidad. |
| **Autoload** | Un store global (Context / Zustand) | Nodo que vive siempre, accesible desde cualquier script por su nombre. Usarlo poco. |
| **Señal** (`signal`) | Evento / `addEventListener` | Un nodo emite (`emit()`), otros se suscriben (`connect()`). |

### Regla "call down, signal up"

Igual que en React los datos bajan por props y los eventos suben por callbacks: un padre **llama métodos** de sus hijos, y un hijo **emite señales** que el padre escucha. Un hijo nunca busca a su padre para mandarle órdenes. Así cada escena se puede probar sola.

## Ciclo de vida

| Función | Cuándo corre | Equivalente web |
|---|---|---|
| `_init()` | Al crear el objeto en memoria | `constructor` |
| `_ready()` | Una vez, cuando el nodo y todos sus hijos ya están en el árbol | `useEffect(() => {}, [])` / `componentDidMount` |
| `_process(delta)` | Cada frame dibujado (60/s a 60 FPS) | `requestAnimationFrame` |
| `_physics_process(delta)` | A ritmo fijo (60/s por defecto), aunque los FPS bajen | `setInterval` a ritmo fijo, sincronizado con la física |
| `_input(event)` / `_unhandled_input(event)` | Al llegar un toque, tecla o movimiento | `addEventListener`. `_unhandled_input` solo recibe lo que la UI no consumió (como un listener en `document` después de `stopPropagation`). |
| `_exit_tree()` | Al quitar el nodo del árbol | Cleanup de `useEffect` / `componentWillUnmount` |

`delta` son los segundos desde el frame anterior (≈0.016 a 60 FPS). Multiplicar todo movimiento por `delta` hace que la velocidad sea la misma a 30 o a 60 FPS.

Regla práctica: lo visual y la UI en `_process`; el movimiento de personajes y colisiones en `_physics_process`.

## Pantalla en vertical

Configurado en `project.godot`:

- **Tamaño base 720x1280** con `stretch mode = canvas_items` y `aspect = expand`. Es como diseñar mobile-first con un viewport de referencia: la UI se escala al tamaño real, y en pantallas más altas (20:9) se gana espacio extra en vez de barras negras.
- **Orientación portrait** fija (`display/window/handheld/orientation`).
- **Safe area**: `ui/safe_area/safe_area_container.gd` mete la UI dentro de la zona segura (lejos del notch y de la barra de gestos). Es el `env(safe-area-inset-*)` de CSS. Toda la UI va dentro de un `SafeAreaContainer`.
- **Modo inmersivo** activado en el export de Android (oculta las barras del sistema).

## Renderer

`Mobile` (Vulkan), con fallback automático a OpenGL ES 3 en celulares sin buen soporte de Vulkan. Se revalúa contra `Compatibility` en la fase 2 (pipeline pixel art).

## GDScript en 30 segundos

```gdscript
extends Node3D                      # "clase base", como extends React.Component

signal died(cause: String)          # evento que otros pueden escuchar

@export var speed: float = 5.0      # prop editable en el Inspector
var _hp: int = 100                  # estado privado (por convención, prefijo _)

func take_damage(amount: int) -> void:   # tipado estático, como TypeScript
	_hp -= amount
	if _hp <= 0:
		died.emit("damage")
```

Indenta con **tabs** (como Python, la indentación es sintaxis).
