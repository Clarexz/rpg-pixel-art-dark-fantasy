class_name OneHandControls
extends Control
## Controles de exploración para UN pulgar, en vertical.
##
##   ┌───────────────┐
##   │               │
##   │      (+)      │   arriba: nada (la mano no llega cómoda)
##   │          [PI] │
##   │          [AT] │   botones del lado de la mano (zurdo = a la izquierda)
##   │   ( stick )   │   abajo: stick fijo; toca en la zona y arrastra
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
## Ancla del conjunto stick + botones (coordenadas globales). Es fija: siempre
## queda en la posición de reposo (ajustada para que todo quepa en pantalla).
var _anchor: Vector2 = Vector2.ZERO
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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for child: Node in find_children("*", "ActionButton", true, false):
		_buttons.append(child as ActionButton)
	resized.connect(_layout)
	_layout()


func add_blocker(control: Control) -> void:
	_blockers.append(control)


## Separación del botón de ataque respecto al borde del stick (mano derecha).
const BASE_STICK_RADIUS: float = 95.0
const ATTACK_GAP: float = 62.0
## Texturas pixel art del stick (estilo "Materiales").
const STICK_BASE_TEX: Texture2D = preload("res://assets/ui/controls/stick_base.png")
const STICK_KNOB_TEX: Texture2D = preload("res://assets/ui/controls/stick_knob.png")
const ATTACK_LIFT: float = 0.0  # centrado con el stick (pedido de Caleb)
## Espacio plano entre el cuadrado de ataque y la media luna de la piedra.
const STONE_GAP: float = 14.0
## Posición de reposo del stick (a escala 1): separación del centro del stick
## al borde del lado de la mano y al borde inferior, descontando el radio.
const REST_SIDE_GAP: float = 204.0
const REST_BOTTOM_GAP: float = 267.0


## Radio del stick ya escalado (el modo una mano ignora joystick_radius).
func _stick_radius() -> float:
	return BASE_STICK_RADIUS * settings.controls_scale


## Rectángulos del conjunto relativos al ancla: [stick, ataque, piedra].
## Mano derecha: botones a la izquierda del stick; zurdo = reflejo en X.
func _cluster_rects() -> Array[Rect2]:
	var s: float = settings.controls_scale
	var r: float = _stick_radius()
	var atk_size: Vector2 = _attack_button.get_box_size()
	var stone_size: Vector2 = _scan_button.get_box_size()
	var atk_center: Vector2 = Vector2(-(r + ATTACK_GAP * s), -ATTACK_LIFT * s)
	var stone_center: Vector2 = Vector2(
		atk_center.x, atk_center.y - atk_size.y * 0.5 - STONE_GAP * s - stone_size.y * 0.5)
	if settings.left_handed:
		atk_center.x = -atk_center.x
		stone_center.x = -stone_center.x
	# El stick incluye el aro de sprint (r + 8).
	var stick_r: float = r + 8.0 * s
	return [
		Rect2(Vector2(-stick_r, -stick_r), Vector2(stick_r, stick_r) * 2.0),
		Rect2(atk_center - atk_size * 0.5, atk_size),
		Rect2(stone_center - stone_size * 0.5, stone_size),
	]


## Acerca el ancla lo necesario para que todo el conjunto quepa en el control.
func _clamp_anchor(pos: Vector2) -> Vector2:
	var box: Rect2 = Rect2()
	var first: bool = true
	for rect: Rect2 in _cluster_rects():
		box = rect if first else box.merge(rect)
		first = false
	var area: Rect2 = get_global_rect()
	var lo: Vector2 = area.position - box.position
	var hi: Vector2 = area.end - box.end
	# Si el conjunto no cabe (pantalla diminuta), centra en vez de invertir el rango.
	var out: Vector2 = pos
	out.x = (lo.x + hi.x) * 0.5 if lo.x > hi.x else clampf(pos.x, lo.x, hi.x)
	out.y = (lo.y + hi.y) * 0.5 if lo.y > hi.y else clampf(pos.y, lo.y, hi.y)
	return out


## Acomoda los botones alrededor del ancla. Se llama al cambiar el tamaño,
## el modo zurdo o el ancla.
func _layout() -> void:
	if settings == null or not is_node_ready():
		return
	_attack_button.visual_scale = settings.controls_scale
	_scan_button.visual_scale = settings.controls_scale
	# El ancla es fija: siempre el reposo, ajustado para que el conjunto quepa.
	_anchor = _clamp_anchor(_rest_center())
	if _finger == -1:
		_center = _anchor
	var rects: Array[Rect2] = _cluster_rects()
	var buttons: Array[ActionButton] = [_attack_button, _scan_button]
	for i: int in buttons.size():
		var button: ActionButton = buttons[i]
		button.size = button.get_box_size()
		button.position = _anchor + rects[i + 1].position - global_position
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
	# Si el toque cae en dos botones a la vez, gana el de centro más cercano.
	var hit: ActionButton = null
	for button: ActionButton in _buttons:
		if not button.is_visible_in_tree() or not button.hit_test(pos):
			continue
		if hit == null or pos.distance_to(button.hit_center()) < pos.distance_to(hit.hit_center()):
			hit = button
	if hit != null:
		_button_fingers[index] = hit
		hit.set_pressed(true)
		settings.pulse(0.5)
		action_pressed.emit(hit.action)
		return true
	if _finger == -1 and _in_stick_zone(pos):
		_finger = index
		# El stick no se muda: se maneja con el toque relativo al centro fijo.
		_center = _anchor
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
	var radius: float = _stick_radius()
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
	var s: float = settings.controls_scale
	var r: float = _stick_radius()
	var x: float = rect.end.x - r - REST_SIDE_GAP * s
	if settings.left_handed:
		x = rect.position.x + r + REST_SIDE_GAP * s
	return Vector2(x, rect.end.y - r - REST_BOTTOM_GAP * s)


func _draw() -> void:
	if settings == null:
		return
	var s: float = settings.controls_scale
	var r: float = _stick_radius()
	var active: bool = _finger != -1
	var center: Vector2 = (_center if active else _anchor) - global_position
	var knob: Vector2 = (_knob if active else _anchor) - global_position
	var alpha: float = 0.75 if active else 0.6
	var tex_tint: Color = Color(1, 1, 1, 1.0 if active else 0.9)
	draw_texture_rect(STICK_BASE_TEX, Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0), false, tex_tint)
	if _sprinting:
		draw_arc(center, r + 8.0 * s, 0.0, TAU, 64, Color(1, 0.8, 0.2, 0.8), 4.0 * s, true)
	# Las flechas llevan una sombra oscura para leerse sobre el café claro.
	_draw_hints(center + Vector2(1.5, 1.5), r, Color(0.2, 0.12, 0.05, alpha + 0.3))
	_draw_hints(center, r, Color(1, 1, 1, alpha + 0.4))
	var knob_half: float = r * 0.84 * 0.5
	draw_texture_rect(STICK_KNOB_TEX, Rect2(knob - Vector2(knob_half, knob_half), Vector2(knob_half, knob_half) * 2.0), false)


func _draw_hints(center: Vector2, r: float, hint: Color) -> void:
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
