class_name RivalCube
extends StaticBody3D
## Rival de prueba: un cubo flotante con ojos. Placeholder de los rivales de
## verdad. Sabe dos cosas en exploración:
## - Si lo golpeas primero -> duelo con ventaja para ti.
## - Si te quedas cerca sin atacar, te nota ("!") y te embosca -> ventaja suya.
## En el duelo solo hace animaciones; las reglas viven en combat/duel.gd.

signal engaged(rival: RivalCube, advantage: StringName)  # &"player" o &"rival"

## Quién es este rival (nombre, poder, temperamento). Su memoria de ti vive
## aparte, en RivalRegistry, bajo data.id.
@export var data: RivalData = preload("res://rivals/data/test_cube.tres")
var display_name: String = "Cubo de prueba"
var max_hp: int = 90
## A esta distancia (m) la piedra empieza a vibrar.
@export var sense_radius: float = 10.0
## A esta distancia te nota y empieza a llenarse su "!".
@export var notice_radius: float = 3.2
## Segundos cerca de él antes de que te embosque.
@export var notice_time: float = 1.6

var hp: int
var in_combat: bool = false
## Mientras sea > 0 no inicia duelos (después de huir o de pelear).
var cooldown: float = 0.0
var alive: bool = true
## Hacia dónde es "derecha" desde los ojos del jugador durante el duelo.
var view_right: Vector3 = Vector3.RIGHT

var _home: Transform3D
var _notice: float = 0.0
var _time: float = 0.0
var _mat: StandardMaterial3D
var _base_color: Color

@onready var _body: Node3D = $Body
@onready var _mesh: MeshInstance3D = $Body/Mesh
@onready var _guard: MeshInstance3D = $Body/Mesh/Guard
@onready var _label: Label3D = $Label


func _ready() -> void:
	add_to_group("rival")
	add_to_group("assist_target")
	_home = global_transform
	display_name = data.display_name
	max_hp = data.max_hp
	hp = max_hp
	_mat = (_mesh.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
	_mesh.material_override = _mat
	_base_color = _mat.albedo_color
	_guard.hide()
	_label.text = ""


func _process(delta: float) -> void:
	_time += delta
	# Flotar de arriba a abajo (siempre, también en duelo).
	_body.position.y = sin(_time * 2.2) * 0.08
	if in_combat or not alive:
		return
	cooldown = maxf(cooldown - delta, 0.0)
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()
	if dist < sense_radius and dist > 0.1:
		# Voltear a verte poco a poco.
		var target_yaw: float = atan2(to_player.x, to_player.z) + PI
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 2.0, 0.0, 1.0))
	if dist < notice_radius and cooldown <= 0.0:
		_notice += delta
	else:
		_notice = maxf(_notice - delta * 2.0, 0.0)
	var alarm: float = clampf(_notice / notice_time, 0.0, 1.0)
	_mat.albedo_color = _base_color.lerp(Color(0.9, 0.15, 0.15), alarm)
	_label.text = "!" if alarm > 0.05 else ""
	_label.modulate.a = alarm
	if _notice >= notice_time:
		_notice = 0.0
		engaged.emit(self, &"rival")


## Qué tan cerca está el jugador: 0 = fuera del radio, 1 = encima.
func closeness_to(point: Vector3) -> float:
	if not alive or in_combat or cooldown > 0.0:
		return 0.0
	var d: float = Vector3(point.x - global_position.x, 0.0, point.z - global_position.z).length()
	return clampf(1.0 - d / sense_radius, 0.0, 1.0)


## Golpe en exploración (lo llama Player.attack): ¡primer golpe!
func take_hit(_push_dir: Vector3) -> void:
	if in_combat or not alive or cooldown > 0.0:
		return
	_notice = 0.0
	engaged.emit(self, &"player")


# --- Animaciones del duelo ------------------------------------------------

func enter_duel(spot: Vector3, look_at_point: Vector3) -> void:
	in_combat = true
	_notice = 0.0
	_label.text = ""
	_mat.albedo_color = _base_color
	global_position = spot
	var look: Vector3 = Vector3(look_at_point.x, spot.y, look_at_point.z)
	if spot.distance_to(look) > 0.01:
		look_at(look, Vector3.UP, true)  # true = los ojos (+Z) ven al jugador


func leave_duel(result: StringName) -> void:
	in_combat = false
	global_transform = _home
	_body.scale = Vector3.ONE
	_body.position.x = 0.0
	_body.rotation = Vector3.ZERO
	match result:
		&"win":
			# Prototipo: reaparece pronto para poder volver a probar.
			alive = false
			visible = false
			get_tree().create_timer(4.0, false).timeout.connect(_respawn)
		&"fled":
			cooldown = 5.0
		_:
			cooldown = 3.0


func _respawn() -> void:
	hp = max_hp
	alive = true
	visible = true
	cooldown = 2.0


## Aviso antes de atacar: se hace para atrás y se inclina hacia ese lado.
func telegraph(side: int, windup: float) -> void:
	var offset: Vector3 = _local_side(side) * 0.35
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(_body, "position:x", offset.x, windup * 0.6)
	tween.tween_property(_body, "rotation:z", -offset.x * 0.8, windup * 0.6)
	_flash(Color(1.0, 0.5, 0.2), windup)


## El golpe: se lanza hacia el jugador y regresa.
func strike() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_body, "position:z", 0.9, 0.06)
	tween.tween_property(_body, "position:z", 0.0, 0.25).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(_body, "position:x", 0.0, 0.25)
	tween.parallel().tween_property(_body, "rotation:z", 0.0, 0.25)


## Recibe un golpe del jugador desde ese lado.
func hurt(side: int) -> void:
	_flash(Color(1, 1, 1), 0.2)
	var push: Vector3 = -_local_side(side) * 0.25
	var tween: Tween = create_tween()
	tween.tween_property(_body, "position:x", push.x, 0.04)
	tween.tween_property(_body, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Bloquea tu golpe: aparece un escudo de ese lado.
func show_guard(side: int) -> void:
	_guard.position = _local_side(side) * 0.62 + Vector3(0, 0, 0.35)
	_guard.show()
	_guard.scale = Vector3.ONE * 1.25
	var tween: Tween = create_tween()
	tween.tween_property(_guard, "scale", Vector3.ONE, 0.08)
	tween.tween_interval(0.25)
	tween.tween_callback(_guard.hide)


func die() -> void:
	_flash(Color(1, 1, 1), 0.5)
	var tween: Tween = create_tween()
	tween.tween_property(_body, "scale", Vector3(1.3, 0.2, 1.3), 0.15)
	tween.tween_property(_body, "scale", Vector3.ZERO, 0.3)


## Lado 0/1/2 (izq/centro/der desde el jugador) en coordenadas locales.
func _local_side(side: int) -> Vector3:
	var world: Vector3 = view_right * float(side - 1)
	return global_basis.inverse() * world


func _flash(color: Color, duration: float) -> void:
	_mat.emission_enabled = true
	_mat.emission = color
	_mat.emission_energy_multiplier = 2.5
	var tween: Tween = create_tween()
	tween.tween_property(_mat, "emission_energy_multiplier", 0.0, duration)
