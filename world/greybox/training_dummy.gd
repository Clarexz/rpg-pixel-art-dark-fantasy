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
var _base_y: float = 0.0
var _flash_tween: Tween

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _label: Label3D = $Label


func _ready() -> void:
	add_to_group("scannable")
	# Cada muñeco necesita su propio material para brillar por separado.
	_mesh.material_override = (_mesh.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
	_base_y = _mesh.position.y
	_label.text = ""


func take_hit(push_dir: Vector3) -> void:
	_hits += 1
	_label.text = "Golpes: %d" % _hits
	var mat: StandardMaterial3D = _mesh.material_override
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween().set_parallel()
	mat.emission_enabled = true
	mat.emission = Color(1, 0.4, 0.3)
	mat.emission_energy_multiplier = 2.0
	_flash_tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.25)
	# Sacudida: se inclina en la dirección del golpe y regresa.
	var local_push: Vector3 = global_basis.inverse() * push_dir
	var tilt: Vector3 = Vector3(local_push.z, 0, -local_push.x).normalized() * 0.35
	_mesh.rotation = tilt
	_flash_tween.tween_property(_mesh, "rotation", Vector3.ZERO, 0.35) \
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
