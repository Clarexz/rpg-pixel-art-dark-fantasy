class_name Enemy
extends CharacterBody3D
## Un enemigo en el mundo: un sprite pixel art (billboard) que patrulla, te
## nota, te persigue y, al alcanzarte, empieza el duelo. Sirve igual para
## enemigos comunes y para rivales: lo que cambia es su `data`
## (EnemyData o RivalData). Las reglas del duelo viven en combat/duel.gd;
## aquí solo hay movimiento y animaciones.
##
## Máquina de estados (como un useReducer con estos estados):
##   PATROL -> (te ve) NOTICE -> (se llena el "!") CHASE -> (te alcanza) duelo
##   Si le pegas primero en cualquier momento: duelo con ventaja tuya.

signal engaged(enemy: Enemy, advantage: StringName)  # &"player" o &"rival"

enum State { PATROL, NOTICE, CHASE, COMBAT, DEAD }

## Cuadros de la tira del sprite (ver tools/art/make_enemy_sprites.py).
const F_IDLE_A: int = 0
const F_IDLE_B: int = 1
const F_WINDUP: int = 2
const F_STRIKE: int = 3
const F_HURT: int = 4
const F_DOWN: int = 5
const GRAVITY: float = 18.0

@export var data: EnemyData
## A esta distancia (m) la piedra empieza a vibrar.
@export var sense_radius: float = 10.0
## A esta distancia te ve y empieza a llenarse su "!".
@export var sight_radius: float = 6.5
## Segundos viéndote antes de perseguirte.
@export var notice_time: float = 0.9
## Si te alejas más que esto mientras te persigue, se rinde.
@export var give_up_radius: float = 13.0
## A esta distancia te alcanza y empieza el duelo (emboscada).
@export var catch_radius: float = 1.5
## Qué tan lejos de su casa pasea.
@export var patrol_radius: float = 3.0
@export var walk_speed: float = 1.0
## Segundos para reaparecer después de vencerlo (prototipo).
@export var respawn_time: float = 15.0

var state: State = State.PATROL
var display_name: String = ""
var max_hp: int = 90
var hp: int = 90
## Mientras sea > 0 no te persigue ni inicia duelos (después de huir o pelear).
var cooldown: float = 0.0
## Hacia dónde es "derecha" desde los ojos del jugador durante el duelo.
var view_right: Vector3 = Vector3.RIGHT

var _home: Transform3D
var _target: Vector3
var _wait: float = 0.0
var _notice: float = 0.0
var _anim: float = 0.0
var _pose_lock: float = 0.0
var _charging: bool = false
var _sprite_base: Vector3
var _tween: Tween

@onready var _sprite: Sprite3D = $Sprite
@onready var _guard: MeshInstance3D = $Guard
@onready var _label: Label3D = $Label
@onready var _shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("assist_target")
	_home = global_transform
	_target = global_position
	display_name = data.display_name
	max_hp = data.max_hp
	hp = max_hp
	_sprite.texture = data.sprite
	_sprite.hframes = 6
	_sprite.pixel_size = data.pixel_size
	# Los pies (fila 47 de 48) quedan en el piso.
	_sprite.position.y = 24.0 * data.pixel_size
	_sprite_base = _sprite.position
	_label.position.y = 48.0 * data.pixel_size + 0.3
	_guard.position.y = 24.0 * data.pixel_size
	_guard.hide()
	_label.text = ""


func is_rival() -> bool:
	return data.is_rival()


func _physics_process(delta: float) -> void:
	_anim += delta
	_pose_lock = maxf(_pose_lock - delta, 0.0)
	if state == State.COMBAT or state == State.DEAD:
		_idle_frame(delta)
		return
	cooldown = maxf(cooldown - delta, 0.0)
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	var to_player: Vector3 = Vector3.ZERO
	var dist: float = INF
	if player:
		to_player = player.global_position - global_position
		to_player.y = 0.0
		dist = to_player.length()
	var can_hunt: bool = cooldown <= 0.0 and player != null and player.get("controls_enabled") != false

	var move: Vector3 = Vector3.ZERO
	match state:
		State.PATROL:
			move = _patrol(delta)
			if can_hunt and dist < sight_radius:
				state = State.NOTICE
		State.NOTICE:
			if not can_hunt or dist > sight_radius + 1.0:
				state = State.PATROL
			else:
				_notice += delta
				if _notice >= notice_time:
					state = State.CHASE
					Sfx.play(&"windup", 0.8)
		State.CHASE:
			if not can_hunt or dist > give_up_radius:
				state = State.PATROL
				_target = _home.origin
			elif dist < catch_radius:
				_notice = 0.0
				engaged.emit(self, &"rival")
				return
			else:
				move = to_player.normalized() * data.chase_speed
	if state != State.NOTICE and state != State.CHASE:
		_notice = maxf(_notice - delta * 2.0, 0.0)
	_update_alarm()

	velocity.x = move.x
	velocity.z = move.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	_walk_frame(move.length() > 0.1)


func _patrol(delta: float) -> Vector3:
	var to: Vector3 = _target - global_position
	to.y = 0.0
	if to.length() < 0.3:
		_wait -= delta
		if _wait <= 0.0:
			var a: float = randf() * TAU
			_target = _home.origin + Vector3(cos(a), 0.0, sin(a)) * randf_range(0.5, patrol_radius)
			_wait = randf_range(1.0, 2.5)
		return Vector3.ZERO
	return to.normalized() * walk_speed


func _update_alarm() -> void:
	var alarm: float = 1.0 if state == State.CHASE else clampf(_notice / notice_time, 0.0, 1.0)
	_label.text = "!" if alarm > 0.05 else ""
	_label.modulate.a = alarm
	if _pose_lock <= 0.0:
		_sprite.modulate = Color.WHITE.lerp(Color(1.0, 0.75, 0.7), alarm * 0.5)


func _walk_frame(walking: bool) -> void:
	if _pose_lock > 0.0:
		return
	var speed: float = 6.0 if walking else 2.0
	_sprite.frame = F_IDLE_A if int(_anim * speed) % 2 == 0 else F_IDLE_B


func _idle_frame(_delta: float) -> void:
	if state == State.DEAD or _pose_lock > 0.0 or _charging:
		return
	_sprite.frame = F_IDLE_A if int(_anim * 2.0) % 2 == 0 else F_IDLE_B


## Qué tan cerca está el jugador: 0 = fuera del radio, 1 = encima.
func closeness_to(point: Vector3) -> float:
	if state == State.DEAD or state == State.COMBAT or cooldown > 0.0:
		return 0.0
	var d: float = Vector3(point.x - global_position.x, 0.0, point.z - global_position.z).length()
	return clampf(1.0 - d / sense_radius, 0.0, 1.0)


## Golpe en exploración (lo llama Player.attack): ¡primer golpe!
func take_hit(_push_dir: Vector3) -> void:
	if state == State.COMBAT or state == State.DEAD or cooldown > 0.0:
		return
	_notice = 0.0
	engaged.emit(self, &"player")


# --- Animaciones del duelo ------------------------------------------------

func enter_duel(spot: Vector3, look_at_point: Vector3) -> void:
	state = State.COMBAT
	_notice = 0.0
	_charging = false
	_label.text = ""
	_sprite.modulate = Color.WHITE
	velocity = Vector3.ZERO
	global_position = spot
	var look: Vector3 = Vector3(look_at_point.x, spot.y, look_at_point.z)
	if spot.distance_to(look) > 0.01:
		look_at(look, Vector3.UP, true)


func leave_duel(result: StringName) -> void:
	_charging = false
	_reset_pose()
	global_transform = _home
	_target = _home.origin
	match result:
		&"win":
			state = State.DEAD
			visible = false
			_shape.disabled = true
			get_tree().create_timer(respawn_time, false).timeout.connect(_respawn)
		&"fled":
			state = State.PATROL
			cooldown = 6.0
		_:
			state = State.PATROL
			cooldown = 3.0


func _respawn() -> void:
	hp = max_hp
	state = State.PATROL
	visible = true
	_shape.disabled = false
	cooldown = 2.0


## Aviso antes de un golpe: pose de "preparando" inclinado hacia ese lado.
func telegraph(side: int, windup: float) -> void:
	_pose(F_WINDUP, windup)
	_lean(side, 0.35, windup * 0.6)
	_tint(Color(1.0, 0.6, 0.4), windup)


## Finta: cambia de lado a medio aviso.
func feint_switch(side: int, remaining: float) -> void:
	_pose(F_WINDUP, remaining)
	_lean(side, 0.45, minf(0.12, remaining))
	_tint(Color(0.8, 0.55, 1.0), remaining)


## Se prepara para el golpe cargado (dura hasta que lo suelta o se lo cortas).
func charge_up() -> void:
	_charging = true
	_sprite.frame = F_WINDUP
	_tint(Color(1.0, 0.85, 0.3), 1.0)
	_kill_tween()
	_tween = create_tween().set_loops(4)
	_tween.tween_property(_sprite, "scale", Vector3.ONE * 1.08, 0.15)
	_tween.tween_property(_sprite, "scale", Vector3.ONE, 0.15)


func cancel_charge() -> void:
	_charging = false
	_reset_pose()
	_pose(F_HURT, 0.4)


func strike() -> void:
	_charging = false
	_pose(F_STRIKE, 0.3)
	var forward: Vector3 = global_basis.inverse() * (global_basis.z * 0.6)
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_sprite, "position", _sprite_base + forward, 0.06)
	_tween.tween_property(_sprite, "position", _sprite_base, 0.25).set_trans(Tween.TRANS_BACK)


## Recibe un golpe del jugador desde ese lado.
func hurt(side: int) -> void:
	_pose(F_HURT, 0.3)
	_flash(Color(3, 3, 3), 0.2)
	var push: Vector3 = -_local_side(side) * 0.25
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_sprite, "position", _sprite_base + push, 0.04)
	_tween.tween_property(_sprite, "position", _sprite_base, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Bloquea tu golpe: aparece un escudo de ese lado.
func show_guard(side: int) -> void:
	_guard.position = Vector3(0, _sprite_base.y, 0) + _local_side(side) * 0.6 + Vector3(0, 0, 0.35)
	_guard.show()
	_guard.scale = Vector3.ONE * 1.25
	var tween: Tween = create_tween()
	tween.tween_property(_guard, "scale", Vector3.ONE, 0.08)
	tween.tween_interval(0.25)
	tween.tween_callback(_guard.hide)


func die() -> void:
	_charging = false
	_kill_tween()
	_sprite.frame = F_DOWN
	_pose_lock = 99.0
	_flash(Color(3, 3, 3), 0.5)


# --- Utilidades ---------------------------------------------------------------

func _pose(frame: int, hold: float) -> void:
	_sprite.frame = frame
	_pose_lock = hold


func _lean(side: int, amount: float, time: float) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_sprite, "position", _sprite_base + _local_side(side) * amount, time)


func _reset_pose() -> void:
	_kill_tween()
	_pose_lock = 0.0
	_sprite.position = _sprite_base
	_sprite.scale = Vector3.ONE
	_sprite.modulate = Color.WHITE


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_sprite.scale = Vector3.ONE


## Lado 0/1/2 (izq/centro/der desde el jugador) en coordenadas locales.
func _local_side(side: int) -> Vector3:
	var world: Vector3 = view_right * float(side - 1)
	return global_basis.inverse() * world


func _tint(color: Color, duration: float) -> void:
	_sprite.modulate = color
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, duration).set_ease(Tween.EASE_IN)


func _flash(color: Color, duration: float) -> void:
	_sprite.modulate = color
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, duration)
