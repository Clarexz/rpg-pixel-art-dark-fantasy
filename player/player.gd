class_name Player
extends CharacterBody3D
## Jugador en primera persona. No sabe nada de pantallas táctiles: recibe
## órdenes ("call down") desde quien lo controla (TouchControls o el teclado)
## y avisa lo que pasó con señales ("signal up").
##
## Analogía web: un componente "tonto" que recibe props/métodos y emite eventos.
## Así el mismo Player sirve con joystick táctil, teclado o un gamepad.

signal attacked(hit_something: bool)
signal scanned(target: Node3D)

@export var settings: ControlSettings

@export_group("Movimiento")
@export var walk_speed: float = 4.5
@export var sprint_speed: float = 7.5
## Qué tan rápido alcanza la velocidad objetivo (más alto = más "pegado").
@export var acceleration: float = 14.0
@export var air_control: float = 0.35
@export var jump_velocity: float = 4.8

@export_group("Ataque")
@export var attack_range: float = 2.6
@export var attack_cooldown: float = 0.45
@export var scan_range: float = 25.0

## Dirección de movimiento pedida, en coordenadas del joystick:
## x = derecha, y = abajo (como la pantalla). Largo 0..1.
var move_input: Vector2 = Vector2.ZERO
var sprinting: bool = false
## Mientras sea true, ataca cada vez que termina el cooldown (mantener presionado).
var attack_held: bool = false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _pitch: float = 0.0
var _attack_timer: float = 0.0
var _jump_queued: bool = false
var _keyboard_was_moving: bool = false

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _attack_ray: RayCast3D = $Head/Camera3D/AttackRay
@onready var _weapon: Node3D = $Head/Camera3D/WeaponPivot


func _ready() -> void:
	if settings == null:
		settings = ControlSettings.load_or_default()
	_attack_ray.target_position = Vector3(0, 0, -attack_range)
	apply_settings()


## Llamar después de cambiar `settings` (p. ej. desde el panel de ajustes).
func apply_settings() -> void:
	_camera.fov = settings.fov


## Gira la cámara. `drag` es lo que se movió el dedo, en píxeles de UI.
func add_look(drag: Vector2) -> void:
	var sens: float = settings.look_sensitivity
	rotate_y(deg_to_rad(-drag.x * sens))
	var y_sign: float = 1.0 if settings.invert_y else -1.0
	_pitch += deg_to_rad(drag.y * sens * settings.vertical_ratio * y_sign)
	_pitch = clampf(_pitch, deg_to_rad(-85.0), deg_to_rad(85.0))
	_head.rotation.x = _pitch


func jump() -> void:
	_jump_queued = true


func attack() -> void:
	if _attack_timer > 0.0:
		return
	_attack_timer = attack_cooldown
	_swing_weapon()
	_attack_ray.force_raycast_update()
	var hit: bool = false
	if _attack_ray.is_colliding():
		var target: Object = _attack_ray.get_collider()
		if target.has_method("take_hit"):
			var push_dir: Vector3 = -_camera.global_basis.z
			target.take_hit(push_dir)
			hit = true
	# Golpe que conecta vibra más fuerte que un golpe al aire.
	settings.pulse(2.0 if hit else 0.6)
	attacked.emit(hit)


## Busca el objetivo "escaneable" más centrado en la mira.
func scan() -> void:
	var forward: Vector3 = -_camera.global_basis.z
	var best: Node3D = null
	var best_dot: float = 0.9  # ~25° alrededor de la mira
	for node: Node in get_tree().get_nodes_in_group("scannable"):
		var target: Node3D = node as Node3D
		var to_target: Vector3 = target.global_position - _camera.global_position
		if to_target.length() > scan_range:
			continue
		var dot: float = forward.dot(to_target.normalized())
		if dot > best_dot:
			best_dot = dot
			best = target
	if best and best.has_method("reveal"):
		best.reveal()
	settings.pulse(1.0 if best else 0.4)
	scanned.emit(best)


# _physics_process corre a ritmo fijo (60/s). Aquí va todo lo que mueve
# cuerpos con colisiones.
func _physics_process(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	if attack_held:
		attack()

	if not is_on_floor():
		velocity.y -= _gravity * delta
	if _jump_queued and is_on_floor():
		velocity.y = jump_velocity
		settings.pulse(0.5)
	_jump_queued = false

	# Joystick (x derecha, y abajo) -> dirección en el mundo relativa a
	# hacia dónde mira el jugador. "Arriba" en el joystick = adelante (-Z).
	var local: Vector3 = Vector3(move_input.x, 0.0, move_input.y)
	var wish: Vector3 = global_basis * local
	var speed: float = sprint_speed if sprinting else walk_speed
	var target_vel: Vector3 = wish * speed
	var accel: float = acceleration if is_on_floor() else acceleration * air_control
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.lerp(target_vel, clampf(accel * delta, 0.0, 1.0))
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	move_and_slide()


# Controles de teclado + mouse para probar en la compu (no estorban en móvil).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		add_look((event as InputEventMouseMotion).relative)
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		match (event as InputEventKey).physical_keycode:
			KEY_SPACE:
				jump()
			KEY_F:
				attack()
			KEY_E:
				scan()
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_M:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	if OS.has_feature("mobile"):
		return
	var keys: Vector2 = Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)),
	)
	if keys != Vector2.ZERO:
		move_input = keys.normalized()
		sprinting = Input.is_physical_key_pressed(KEY_SHIFT)
	elif _keyboard_was_moving:
		move_input = Vector2.ZERO
		sprinting = false
	_keyboard_was_moving = keys != Vector2.ZERO



func _swing_weapon() -> void:
	# Tween = animación por código, como element.animate() en la web.
	var tween: Tween = create_tween()
	tween.tween_property(_weapon, "rotation_degrees", Vector3(-70, 25, -20), 0.08)
	tween.tween_property(_weapon, "rotation_degrees", Vector3.ZERO, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
