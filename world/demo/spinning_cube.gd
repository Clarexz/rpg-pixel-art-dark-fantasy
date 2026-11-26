extends MeshInstance3D
## Cubo que gira. Toca la pantalla para invertir el giro (prueba de input táctil).

## @export = "prop" editable desde el Inspector del editor (como props de React).
@export var degrees_per_second: float = 90.0

var _direction: float = 1.0


# _ready corre una vez, cuando el nodo y sus hijos ya están en el árbol.
# Analogía web: useEffect(() => {...}, []) / componentDidMount.
func _ready() -> void:
	print("Cubo listo. Toca la pantalla para invertir el giro.")


# Cada frame: rotar según el tiempo transcurrido (delta) para que la velocidad
# sea la misma a 30 o a 60 FPS.
func _process(delta: float) -> void:
	rotate_y(deg_to_rad(degrees_per_second) * _direction * delta)
	rotate_x(deg_to_rad(degrees_per_second * 0.5) * delta)


# Input que nadie más consumió (la UI tiene prioridad). Como un listener
# en document que solo recibe lo que no hizo stopPropagation().
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_direction *= -1.0
