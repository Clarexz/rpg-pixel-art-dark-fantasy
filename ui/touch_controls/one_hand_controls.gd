class_name OneHandControls
extends Control
## Controles de exploración para UN pulgar, en vertical.
##
##   ┌───────────────┐
##   │               │
##   │      (+)      │   arriba: nada (la mano no llega cómoda)
##   │          [PI] │
##   │          [AT] │   botones del lado de la mano (zurdo = a la izquierda)
##   │   ( stick )   │   abajo: pon el pulgar donde sea y arrastra
##   └───────────────┘
##
## Dos modos (se eligen en Ajustes para comparar):
## - Libre ("stick de tanque"): arriba/abajo = avanzar/retroceder,
##   a los lados = girar. Así un solo pulgar camina Y mira.
## - Por casillas: cada empujón es un paso de una casilla o un giro de 90°
##   (como los dungeon crawlers clásicos). Mantener empujado repite.
##
## Igual que TouchControls, solo traduce dedos a intenciones ("signal up").

signal stick_changed(turn: float, forward: float, sprint: bool)
signal step_requested(direction: Vector2i)
signal action_pressed(action: StringName)
signal action_released(action: StringName)

## Fracción del alto (desde abajo) donde puedes empezar a arrastrar el stick.
@export_range(0.3, 0.8) var stick_zone_height: float = 0.5
## En modo casillas: segundos antes de repetir el paso si mantienes empujado.
@export var grid_repeat_delay: float = 0.32

var settings: ControlSettings
var grid_mode: bool = false

var _finger: int = -1
var _center: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO
var _sprinting: bool = false
var _held_dir: Vector2i = Vector2i.ZERO
var _repeat_timer: float = 0.0
var _button_fingers: Dictionary = {}  # index -> ActionButton
var _buttons: Array[ActionButton] = []
var _blockers: Array[Control] = []

@onready var _attack_button: ActionButton = $AttackButton
@onready var _scan_button: ActionButton = $ScanButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in find_children("*", "ActionButton", true, false):
		_buttons.append(child as ActionButton)
	resized.connect(_layout)
	_layout()


func add_blocker(control: Control) -> void:
	_blockers.append(control)


## Acomoda los botones del lado de la mano. Llamar al cambiar "Modo zurdo".
func _layout() -> void:
	if settings == null or not is_node_ready():
		return
	var w: float = size.x
	var h: float = size.y
	var left: bool = settings.left_handed
	# Coordenadas pensadas para mano derecha; en zurdo se reflejan en X.
	var spots: Array = [
		[_attack_button, Vector2(w - 120.0, h - 470.0)],
		[_scan_button, Vector2(w - 100.0, h - 650.0)],
	]
	for spot: Array in spots:
		var button: ActionButton = spot[0]
		var c: Vector2 = spot[1]
		if left:
			c.x = w - c.x
		button.position = c - button.size * 0.5
	queue_redraw()


func release_all() -> void:
	if _finger != -1:
		_end_stick()
	for index: int in _button_fingers.keys():
		_release_button(index)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			if _on_touch_down(touch.index, touch.position):
				get_viewport().set_input_as_handled()
		else:
			_on_touch_up(touch.index)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index == _finger:
			_update_stick(drag.position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		release_all()


func _on_touch_down(index: int, pos: Vector2) -> bool:
	for blocker: Control in _blockers:
		if blocker.is_visible_in_tree() and blocker.get_global_rect().has_point(pos):
			return false
	for button: ActionButton in _buttons:
		if button.is_visible_in_tree() and button.hit_test(pos):
			_button_fingers[index] = button
			button.set_pressed(true)
			settings.pulse(0.5)
			action_pressed.emit(button.action)
			return true
	if _finger == -1 and _in_stick_zone(pos):
		_finger = index
		_center = _clamp_center(pos)
		_update_stick(pos)
		return true
	return false


func _on_touch_up(index: int) -> void:
	if index == _finger:
		_end_stick()
	elif _button_fingers.has(index):
		_release_button(index)


func _release_button(index: int) -> void:
	var button: ActionButton = _button_fingers[index]
	_button_fingers.erase(index)
	button.set_pressed(false)
	action_released.emit(button.action)


func _update_stick(pos: Vector2) -> void:
	var radius: float = settings.joystick_radius
	var offset: Vector2 = (pos - _center).limit_length(radius)
	_knob = _center + offset
	var amount: float = offset.length() / radius
	if grid_mode:
		_update_grid(offset, amount)
	else:
		_update_tank(offset, amount)
	queue_redraw()


func _update_tank(offset: Vector2, amount: float) -> void:
	var dir: Vector2 = Vector2.ZERO
	if amount > settings.joystick_deadzone:
		var scaled: float = (amount - settings.joystick_deadzone) / (1.0 - settings.joystick_deadzone)
		dir = offset.normalized() * scaled
	# Zona muerta extra en el giro para que "derecho" sea fácil de sostener,
	# y curva cuadrática: giros finos cerca del centro, rápidos en la orilla.
	var turn: float = 0.0
	if absf(dir.x) > 0.12:
		var t: float = (absf(dir.x) - 0.12) / 0.88
		turn = signf(dir.x) * t * t
	var forward: float = -dir.y
	var sprint: bool = amount >= settings.sprint_threshold and forward > 0.8
	if sprint and not _sprinting:
		settings.pulse(0.7)
	_sprinting = sprint
	stick_changed.emit(turn, forward, sprint)


func _update_grid(offset: Vector2, amount: float) -> void:
	var dir: Vector2i = Vector2i.ZERO
	if amount > 0.45:
		if absf(offset.x) > absf(offset.y):
			dir = Vector2i(int(signf(offset.x)), 0)
		else:
			dir = Vector2i(0, int(signf(offset.y)))
	if dir != _held_dir:
		_held_dir = dir
		_repeat_timer = grid_repeat_delay
		if dir != Vector2i.ZERO:
			step_requested.emit(dir)


func _process(delta: float) -> void:
	if not grid_mode or _held_dir == Vector2i.ZERO:
		return
	_repeat_timer -= delta
	if _repeat_timer <= 0.0:
		_repeat_timer = grid_repeat_delay
		step_requested.emit(_held_dir)


func _end_stick() -> void:
	_finger = -1
	_sprinting = false
	_held_dir = Vector2i.ZERO
	stick_changed.emit(0.0, 0.0, false)
	queue_redraw()


func _in_stick_zone(pos: Vector2) -> bool:
	var rect: Rect2 = get_global_rect()
	return pos.y >= rect.end.y - rect.size.y * stick_zone_height and rect.has_point(pos)


## Dónde se dibuja el stick cuando nadie lo toca: abajo, del lado de la mano.
func _rest_center() -> Vector2:
	var rect: Rect2 = get_global_rect()
	var r: float = settings.joystick_radius
	var x: float = rect.end.x - r - 150.0
	if settings.left_handed:
		x = rect.position.x + r + 150.0
	return Vector2(x, rect.end.y - r - 70.0)


func _clamp_center(pos: Vector2) -> Vector2:
	var rect: Rect2 = get_global_rect().grow(-settings.joystick_radius * 0.6)
	return pos.clamp(rect.position, rect.end)


func _draw() -> void:
	if settings == null:
		return
	var r: float = settings.joystick_radius
	var active: bool = _finger != -1
	var center: Vector2 = (_center if active else _rest_center()) - global_position
	var knob: Vector2 = (_knob if active else _rest_center()) - global_position
	var alpha: float = 0.5 if active else 0.22
	draw_circle(center, r, Color(0, 0, 0, alpha * 0.5))
	draw_arc(center, r, 0.0, TAU, 64, Color(1, 1, 1, alpha), 3.0, true)
	if _sprinting:
		draw_arc(center, r + 8.0, 0.0, TAU, 64, Color(1, 0.8, 0.2, 0.8), 4.0, true)
	var hint: Color = Color(1, 1, 1, alpha + 0.1)
	if grid_mode:
		# Cuatro flechas: paso adelante/atrás, giro izquierda/derecha.
		for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var tip: Vector2 = center + d * (r - 10.0)
			var side: Vector2 = d.orthogonal() * 16.0
			draw_colored_polygon(PackedVector2Array([tip, tip - d * 26.0 + side, tip - d * 26.0 - side]), hint)
	else:
		# Flechas curvas a los lados = girar; arriba = avanzar.
		draw_arc(center, r - 14.0, PI - 0.5, PI + 0.5, 12, hint, 4.0, true)
		draw_arc(center, r - 14.0, -0.5, 0.5, 12, hint, 4.0, true)
		var tip: Vector2 = center + Vector2.UP * (r - 10.0)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-16, 26), tip + Vector2(16, 26)]), hint)
	draw_circle(knob, r * 0.42, Color(1, 1, 1, alpha + 0.15))
