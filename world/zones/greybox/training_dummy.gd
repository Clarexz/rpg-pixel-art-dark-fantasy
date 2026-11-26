class_name TrainingDummy
extends StaticBody3D
## Muñeco de práctica: se sacude al recibir golpes y cuenta cuántos lleva.
## También responde al escaneo de la piedra con una lectura placeholder.
##
## Player no conoce esta clase: solo pregunta "¿tienes take_hit()?".
## Analogía web: duck typing, como checar `typeof obj.onHit === "function"`.

## Lectura placeholder del escaneo (en la fase 4 vendrá de la piedra).
@export var power_reading: String = "Similar"

var _hits: int = 0
var _flash_tween: Tween

## Sprite3D "billboard": una imagen plana que siempre gira para mirarte
## (solo en el eje Y, como los enemigos de Doom). Mucho más barato que un
## modelo 3D y es el look pixel art que buscamos.
@onready var _sprite: Sprite3D = $Sprite
@onready var _label: Label3D = $Label


func _ready() -> void:
	add_to_group("scannable")
	_label.text = ""


func take_hit(_push_dir: Vector3) -> void:
	_hits += 1
	_label.text = "Golpes: %d" % _hits
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween().set_parallel()
	# Destello rojo: modulate multiplica el color del sprite (como un filtro CSS).
	_sprite.modulate = Color(1.6, 0.55, 0.45)
	_flash_tween.tween_property(_sprite, "modulate", Color.WHITE, 0.25)
	# Un billboard no se puede inclinar (siempre te mira), así que en vez de
	# sacudirlo lo "aplastamos" y regresa con rebote.
	_sprite.scale = Vector3(1.25, 0.8, 1.0)
	_flash_tween.tween_property(_sprite, "scale", Vector3.ONE, 0.35) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func reveal() -> void:
	_label.text = "Poder: %s" % power_reading
	var tween: Tween = create_tween()
	_label.modulate = Color(0.6, 0.9, 1.0, 1.0)
	tween.tween_interval(2.0)
	tween.tween_property(_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void:
		_label.text = "Golpes: %d" % _hits if _hits > 0 else ""
		_label.modulate = Color.WHITE)
