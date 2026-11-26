class_name BenchGhoul
extends Sprite3D
## Enemigo de relleno para la prueba de estrés: un Sprite3D billboard que
## camina sin rumbo y anima 2 cuadros. Hace el trabajo mínimo que hará un
## enemigo real (moverse y animarse) para que la medición sea honesta.

const SPEED: float = 1.2
const FPS_ANIM: float = 4.0

## Rectángulo (x, z) donde puede caminar. Lo pone el benchmark.
var bounds: Rect2 = Rect2(-10, -10, 20, 20)

var _velocity: Vector3
var _anim_time: float = 0.0


func _ready() -> void:
	var angle: float = randf() * TAU
	_velocity = Vector3(cos(angle), 0.0, sin(angle)) * SPEED * randf_range(0.5, 1.0)
	_anim_time = randf()


func _process(delta: float) -> void:
	position += _velocity * delta
	# Rebota en las orillas del área.
	if position.x < bounds.position.x or position.x > bounds.end.x:
		_velocity.x = -_velocity.x
	if position.z < bounds.position.y or position.z > bounds.end.y:
		_velocity.z = -_velocity.z
	_anim_time += delta
	frame = int(_anim_time * FPS_ANIM) % hframes
