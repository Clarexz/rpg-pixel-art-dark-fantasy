class_name TouchControls
extends Control
## Capa táctil multi-dedo: joystick virtual (mover), arrastre (mirar) y
## botones de acción. Solo traduce dedos a intenciones y las emite como
## señales; no sabe nada del jugador ("signal up").
##
## Cómo se reparte la pantalla en vertical:
##   ┌───────────────┐
##   │               │  arriba: arrastrar = mirar
##   │      (+)      │
##   │               │
##   │ joystick│ mirar│  abajo-izquierda: joystick (aparece donde tocas)
##   │  zona   │ [⚔] │  abajo-derecha: botones; arrastrar sobre ⚔ también mira
##   └───────────────┘
##
## Analogía web: un handler de pointer events que lleva la cuenta de cada
## pointerId (aquí "index" = un dedo) y decide a qué "gesto" pertenece.

signal move_changed(direction: Vector2, sprint: bool)
signal look_dragged(drag: Vector2)
signal action_pressed(action: StringName)
signal action_released(action: StringName)

## Fracción del ancho (desde la izquierda) que ocupa la zona del joystick.
@export_range(0.3, 0.7) var joystick_zone_width: float = 0.5
## Fracción del alto (desde abajo) que ocupa la zona del joystick.
@export_range(0.3, 0.8) var joystick_zone_height: float = 0.55

var settings: ControlSettings

var _joy_finger: int = -1
var _joy_center: Vector2 = Vector2.ZERO
var _joy_knob: Vector2 = Vector2.ZERO
var _joy_sprinting: bool = false
var _look_fingers: Dictionary = {}  # index -> true
var _button_fingers: Dictionary = {}  # index -> ActionButton
var _buttons: Array[ActionButton] = []
var _blockers: Array[Control] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in find_children("*", "ActionButton", true, false):
		_buttons.append(child as ActionButton)
	resized.connect(queue_redraw)


## Controles (p. ej. el botón de ajustes) cuyos toques NO debemos tomar.
func add_blocker(control: Control) -> void:
	_blockers.append(control)


## Suelta todos los dedos. Se llama al perder el foco de la app: si no,
## el joystick se queda "pegado" moviendo al jugador.
func release_all() -> void:
	if _joy_finger != -1:
		_end_joystick()
	_look_fingers.clear()
	for index: int in _button_fingers.keys():
		_release_button(index)
	queue_redraw()


# _input recibe TODOS los eventos antes que la UI normal (como un listener
# en fase de captura). Lo usamos porque necesitamos varios dedos a la vez.
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
		_on_drag(drag.index, drag.position, drag.relative)


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

	if _joy_finger == -1 and _in_joystick_zone(pos):
		_joy_finger = index
		_joy_center = pos if settings.joystick_floating else _rest_center()
		if settings.joystick_floating:
			_joy_center = _clamp_center(_joy_center)
		_update_joystick(pos)
		return true

	_look_fingers[index] = true
	return true


func _on_touch_up(index: int) -> void:
	if index == _joy_finger:
		_end_joystick()
	elif _button_fingers.has(index):
		_release_button(index)
	_look_fingers.erase(index)


func _on_drag(index: int, pos: Vector2, relative: Vector2) -> void:
	if index == _joy_finger:
		_update_joystick(pos)
	elif _look_fingers.has(index):
		look_dragged.emit(relative)
	elif _button_fingers.has(index):
		var button: ActionButton = _button_fingers[index]
		if button.drag_looks:
			look_dragged.emit(relative)


func _release_button(index: int) -> void:
	var button: ActionButton = _button_fingers[index]
	_button_fingers.erase(index)
	button.set_pressed(false)
	action_released.emit(button.action)


func _update_joystick(pos: Vector2) -> void:
	var radius: float = settings.joystick_radius
	var offset: Vector2 = (pos - _joy_center).limit_length(radius)
	_joy_knob = _joy_center + offset
	var amount: float = offset.length() / radius
	var direction: Vector2 = Vector2.ZERO
	if amount > settings.joystick_deadzone:
		# Re-escalar para que justo afuera de la zona muerta empiece en 0.
		var scaled: float = (amount - settings.joystick_deadzone) / (1.0 - settings.joystick_deadzone)
		direction = offset.normalized() * scaled
	# Correr: dedo al borde y apuntando más o menos hacia adelante.
	var sprint: bool = amount >= settings.sprint_threshold and direction.y < -0.5
	if sprint and not _joy_sprinting:
		settings.pulse(0.7)
	_joy_sprinting = sprint
	move_changed.emit(direction, sprint)
	queue_redraw()


func _end_joystick() -> void:
	_joy_finger = -1
	_joy_sprinting = false
	move_changed.emit(Vector2.ZERO, false)
	queue_redraw()


func _in_joystick_zone(pos: Vector2) -> bool:
	var rect: Rect2 = get_global_rect()
	var zone: Rect2 = Rect2(
		rect.position.x,
		rect.end.y - rect.size.y * joystick_zone_height,
		rect.size.x * joystick_zone_width,
		rect.size.y * joystick_zone_height,
	)
	return zone.has_point(pos)


## Dónde descansa el joystick cuando nadie lo toca (y dónde vive si es fijo).
func _rest_center() -> Vector2:
	var rect: Rect2 = get_global_rect()
	var r: float = settings.joystick_radius
	return Vector2(rect.position.x + r + 40.0, rect.end.y - r - 90.0)


## Que el aro completo quepa en pantalla aunque toques muy en la orilla.
func _clamp_center(pos: Vector2) -> Vector2:
	var rect: Rect2 = get_global_rect().grow(-settings.joystick_radius * 0.6)
	return pos.clamp(rect.position, rect.end)


func _draw() -> void:
	if settings == null:
		return
	var r: float = settings.joystick_radius
	var active: bool = _joy_finger != -1
	var center: Vector2 = (_joy_center if active else _rest_center()) - global_position
	var knob: Vector2 = (_joy_knob if active else _rest_center()) - global_position
	var alpha: float = 0.5 if active else 0.2
	draw_circle(center, r, Color(0, 0, 0, alpha * 0.5))
	draw_arc(center, r, 0.0, TAU, 64, Color(1, 1, 1, alpha), 3.0, true)
	if _joy_sprinting:
		draw_arc(center, r + 8.0, 0.0, TAU, 64, Color(1, 0.8, 0.2, 0.8), 4.0, true)
	draw_circle(knob, r * 0.42, Color(1, 1, 1, alpha + 0.15))
