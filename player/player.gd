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

## Tamaño de una casilla en el modo "por casillas" (metros).
@export var grid_size: float = 2.0
## Segundos que tarda un paso / un giro en el modo por casillas.
@export var grid_step_time: float = 0.2
@export var grid_turn_time: float = 0.16

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
## Giro pedido por el stick de una mano (-1 izquierda .. 1 derecha).
var turn_input: float = 0.0
## true = moverse por casillas (pasos y giros de 90°) en vez de libre.
var grid_mode: bool = false
## false mientras hay un duelo: el jugador no camina ni ataca por su cuenta.
var controls_enabled: bool = true
## Dónde reaparece si pierde un duelo.
var spawn_transform: Transform3D

var _grid_busy: bool = false

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
	spawn_transform = global_transform
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
	if _attack_timer > 0.0 or not controls_enabled:
		return
	_attack_timer = attack_cooldown
	swing(1)
	_attack_ray.force_raycast_update()
	var hit: bool = false
	var target: Object = null
	if _attack_ray.is_colliding():
		target = _attack_ray.get_collider()
	if target == null or not target.has_method("take_hit"):
		target = _assist_target()
	if target and target.has_method("take_hit"):
		var push_dir: Vector3 = -_camera.global_basis.z
		target.take_hit(push_dir)
		hit = true
	# Golpe que conecta vibra más fuerte que un golpe al aire.
	settings.pulse(2.0 if hit else 0.6)
	attacked.emit(hit)


## Ayuda para una mano: sin poder mirar arriba/abajo es fácil fallar, así
## que si el rayo no pegó, buscamos un objetivo "asistible" cerca y enfrente.
func _assist_target() -> Node3D:
	var forward: Vector3 = -global_basis.z
	for node: Node in get_tree().get_nodes_in_group("assist_target"):
		var target: Node3D = node as Node3D
		var to_target: Vector3 = target.global_position - global_position
		to_target.y = 0.0
		if to_target.length() <= attack_range + 0.6 and forward.dot(to_target.normalized()) > 0.75:
			return target
	return null


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
	if _jump_queued and is_on_floor() and controls_enabled:
		velocity.y = jump_velocity
		settings.pulse(0.5)
	_jump_queued = false

	if settings.is_one_hand():
		# Con un pulgar no hay cómo mirar arriba/abajo: la vista se nivela sola.
		_pitch = lerpf(_pitch, 0.0, clampf(6.0 * delta, 0.0, 1.0))
		_head.rotation.x = _pitch

	if not controls_enabled or grid_mode:
		# En duelo o por casillas no caminamos libre: solo gravedad.
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# Stick de tanque: a los lados gira el cuerpo en vez de caminar de lado.
	if turn_input != 0.0:
		rotate_y(deg_to_rad(-settings.tank_turn_speed * turn_input * delta))

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
		if settings.is_one_hand():
			# Igual que el stick de una mano: A/D giran, W/S avanzan.
			turn_input = keys.x
			move_input = Vector2(0.0, keys.y)
		else:
			move_input = keys.normalized()
		sprinting = Input.is_physical_key_pressed(KEY_SHIFT)
	elif _keyboard_was_moving:
		move_input = Vector2.ZERO
		turn_input = 0.0
		sprinting = false
	_keyboard_was_moving = keys != Vector2.ZERO



# --- Modo por casillas -------------------------------------------------

func set_grid_mode(on: bool) -> void:
	grid_mode = on
	if on:
		snap_to_grid()


## Centra al jugador en su casilla y lo deja viendo a un punto cardinal.
func snap_to_grid() -> void:
	global_position.x = roundf(global_position.x / grid_size) * grid_size
	global_position.z = roundf(global_position.z / grid_size) * grid_size
	rotation.y = snappedf(rotation.y, PI / 2.0)


## Un paso adelante (1) o atrás (-1). Devuelve false si hay pared o está ocupado.
func grid_step(direction: int) -> bool:
	if _grid_busy or not controls_enabled:
		return false
	var forward: Vector3 = -global_basis.z
	forward.y = 0.0
	var motion: Vector3 = forward.normalized() * grid_size * float(direction)
	# test_move = "¿chocaría si me muevo así?" sin moverse de verdad.
	if test_move(global_transform, motion):
		settings.pulse(0.4)
		return false
	_grid_busy = true
	var tween: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "global_position", global_position + motion, grid_step_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void: _grid_busy = false)
	settings.pulse(0.3)
	return true


## Giro de 90°: 1 = derecha, -1 = izquierda.
func grid_turn(direction: int) -> bool:
	if _grid_busy or not controls_enabled:
		return false
	_grid_busy = true
	var target: float = snappedf(rotation.y, PI / 2.0) - float(direction) * PI / 2.0
	var tween: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "rotation:y", target, grid_turn_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _grid_busy = false)
	return true


# --- Duelo -----------------------------------------------------------------

## Voltea a ver en esa dirección (horizontal) de golpe.
func face_direction(direction: Vector3) -> void:
	rotation.y = atan2(-direction.x, -direction.z)
	_pitch = 0.0
	_head.rotation.x = 0.0


func camera_position() -> Vector3:
	return _camera.global_position


## Sacudida de cámara. strength en metros (0.05 ya se nota).
func shake(strength: float = 0.06, duration: float = 0.18) -> void:
	var tween: Tween = create_tween()
	tween.tween_method(func(t: float) -> void:
		var amount: float = strength * (1.0 - t)
		_camera.h_offset = randf_range(-amount, amount)
		_camera.v_offset = randf_range(-amount, amount), 0.0, 1.0, duration)
	tween.tween_callback(func() -> void:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0)


func respawn() -> void:
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	if grid_mode:
		snap_to_grid()


## Animación del arma. side: 0 = izquierda, 1 = centro, 2 = derecha.
func swing(side: int = 1) -> void:
	# Tween = animación por código, como element.animate() en la web.
	var wind: Vector3 = [Vector3(-20, 70, 40), Vector3(-80, 0, 0), Vector3(-20, -70, -40)][clampi(side, 0, 2)]
	var tween: Tween = create_tween()
	tween.tween_property(_weapon, "rotation_degrees", wind, 0.08)
	tween.tween_property(_weapon, "rotation_degrees", Vector3.ZERO, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
