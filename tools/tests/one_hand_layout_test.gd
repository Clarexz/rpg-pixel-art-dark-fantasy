extends Node
## Prueba del conjunto de exploración a una mano: el stick y los botones
## ATACAR / PIEDRA quedan fijos en la posición de reposo (no siguen al toque),
## no se salen de la pantalla y se reflejan en modo zurdo.
## Corre en CI con: godot --headless --path . res://tools/tests/one_hand_layout_test.tscn

const WORLD: PackedScene = preload("res://world/world.tscn")

var _failures: PackedStringArray = []
var _world: World
var _one: OneHandControls
var _attack: ActionButton
var _stone: ActionButton


func _ready() -> void:
	RivalRegistry.save_enabled = false
	Piedra.save_enabled = false
	Piedra.use_record(PlayerRecord.new())
	Inventory.save_enabled = false
	_world = WORLD.instantiate() as World
	_world.start_zone = load(World.PRACTICE_ZONE)
	add_child(_world)
	_one = _world.get_node("HUD/SafeArea/OneHandControls")
	_attack = _one.get_node("AttackButton")
	_stone = _one.get_node("ScanButton")
	await _frames(10)
	_one.settings.haptics_enabled = false
	_one.settings.left_handed = false
	_world.apply_mode()
	await _frames(3)
	await _run()
	if _failures.is_empty():
		print("ONE HAND LAYOUT TEST OK")
		get_tree().quit(0)
	else:
		for f: String in _failures:
			printerr("ONE HAND LAYOUT TEST FAIL: ", f)
		get_tree().quit(1)


func _run() -> void:
	var rect: Rect2 = _one.get_global_rect()
	var r: float = _one._stick_radius()

	# 0) Los botones llevan sus texturas pixel art.
	print("Paso 0: ATACAR y PIEDRA tienen textura asignada.")
	for button: ActionButton in [_attack, _stone]:
		_check(button.texture != null and button.texture.get_width() > 0, "%s sin textura" % button.label)
		_check(button.texture_pressed != null and button.texture_pressed.get_width() > 0, "%s sin textura apretada" % button.label)

	# 1) El reposo está en la posición nueva y tocar la zona NO mueve el ancla.
	print("Paso 1: el conjunto queda fijo en el reposo aunque toques en otro punto.")
	_check_rest(rect, r, false, "diestro")
	var rest: Vector2 = _one._anchor
	var p: Vector2 = Vector2(rect.get_center().x - 120.0, rect.end.y - 250.0)
	_touch(0, p, true)
	await _frames(2)
	_check_cluster(rest, r, "con el dedo puesto")
	_check(_one._center.distance_to(rest) <= 1.0, "el centro del stick se movió del reposo")
	var expected: Vector2 = (p - rest).limit_length(r)
	_check(_one._knob.distance_to(rest + expected) <= 1.0, "el knob no se desplazó hacia el toque (%s)" % _one._knob)
	_check((_one._knob - rest).normalized().dot((p - rest).normalized()) > 0.99, "el knob no apunta hacia el toque")
	_touch(0, p, false)
	await _frames(5)
	_check_cluster(rest, r, "después de soltar")
	_check(_stone.hit_center().y < _attack.hit_center().y, "la piedra no está arriba del ataque")
	p = rest

	# 2) Tocar ATACAR no mueve el conjunto.
	print("Paso 2: tocar ATACAR no mueve el conjunto.")
	var tap: Vector2 = _attack.hit_center()
	_touch(1, tap, true)
	await _frames(2)
	_touch(1, tap, false)
	await _frames(2)
	_check_cluster(p, r, "tras tocar ATACAR")

	# 3) Tocar junto a los bordes tampoco mueve nada y todo cabe en el control.
	print("Paso 3: junto a los bordes el conjunto sigue fijo y cabe en pantalla.")
	var edge: Vector2 = Vector2(rect.position.x + 5.0, rect.end.y - 100.0)
	_touch(0, edge, true)
	await _frames(2)
	_check_inside(rect, r, "borde izquierdo")
	_touch(0, edge, false)
	await _frames(2)
	_check_inside(rect, r, "borde izquierdo, soltado")
	var edge_r: Vector2 = Vector2(rect.end.x - 5.0, rect.end.y - 5.0)
	_touch(0, edge_r, true)
	await _frames(2)
	_check_inside(rect, r, "esquina inferior derecha")
	_touch(0, edge_r, false)
	await _frames(2)
	_check_cluster(rest, r, "tras tocar los bordes")

	# 4) Zurdo: los botones pasan a la derecha del stick.
	print("Paso 4: en modo zurdo el ataque queda a la derecha del stick.")
	_one.settings.left_handed = true
	_world.apply_mode()
	await _frames(3)
	_check_rest(rect, r, true, "zurdo")
	var anchor: Vector2 = _one._anchor
	_check(absf(_attack.hit_center().x - (anchor.x + r + OneHandControls.ATTACK_GAP * _one.settings.controls_scale)) <= 1.0, "zurdo: ataque no está a R+GAP a la derecha (x=%.1f, ancla=%.1f)" % [_attack.hit_center().x, anchor.x])
	_check(absf(_stone.hit_center().x - _attack.hit_center().x) <= 1.0, "zurdo: la piedra no está sobre el ataque")
	_check_inside(rect, r, "zurdo")
	_one.settings.left_handed = false
	_world.apply_mode()
	await _frames(3)

	# 5) Escala 1.3: stick, botones y separación crecen 1.3x y todo sigue cabiendo.
	print("Paso 5: controls_scale = 1.3 escala el conjunto y cabe en pantalla.")
	_one.settings.controls_scale = 1.0
	_world.apply_mode()
	await _frames(3)
	var r1: float = _one._stick_radius()
	var atk1: Vector2 = _attack.get_box_size()
	var gap1: float = _attack.hit_center().distance_to(_one._anchor) - r1
	_one.settings.controls_scale = 1.3
	_world.apply_mode()
	await _frames(3)
	var r2: float = _one._stick_radius()
	_check(absf(r2 - r1 * 1.3) <= 1.0, "escala: radio del stick %.1f != %.1f" % [r2, r1 * 1.3])
	_check(absf(_attack.get_box_size().x - atk1.x * 1.3) <= 1.0, "escala: caja de ataque %s" % _attack.get_box_size())
	_check(absf(_attack.size.x - atk1.x * 1.3) <= 1.0, "escala: size del nodo de ataque %s" % _attack.size)
	var gap2: float = _attack.hit_center().distance_to(_one._anchor) - r2
	_check(absf(gap2 - gap1 * 1.3) <= 1.0, "escala: separación %.1f != %.1f" % [gap2, gap1 * 1.3])
	_check_inside(rect, r2, "escala 1.3")
	var corner: Vector2 = Vector2(rect.position.x + 2.0, rect.position.y + 2.0)
	_touch(0, corner, true)
	await _frames(2)
	_touch(0, corner, false)
	await _frames(2)
	_check_inside(rect, r2, "escala 1.3, esquina superior")
	_one.settings.controls_scale = 1.0
	_world.apply_mode()
	await _frames(3)

	# 6) Pantalla alta (720x1560, como el celular del diseñador): reposo nuevo.
	print("Paso 6: el reposo es correcto en 720x1560, diestro y zurdo.")
	get_window().size = Vector2i(405, 877)
	await _frames(5)
	rect = _one.get_global_rect()
	r = _one._stick_radius()
	_check(rect.size.y > 1500.0, "la pantalla alta no se aplicó (alto %.0f)" % rect.size.y)
	_check_rest(rect, r, false, "alta, diestro")
	_one.settings.left_handed = true
	_world.apply_mode()
	await _frames(3)
	_check_rest(rect, r, true, "alta, zurdo")
	_one.settings.left_handed = false
	_world.apply_mode()
	await _frames(3)


## Reposo: (borde del lado de la mano -/+ r + 204·s, borde inferior - r - 267·s).
func _check_rest(rect: Rect2, r: float, left: bool, when: String) -> void:
	var s: float = _one.settings.controls_scale
	var x: float = rect.position.x + r + 204.0 * s if left else rect.end.x - r - 204.0 * s
	var want: Vector2 = Vector2(x, rect.end.y - r - 267.0 * s)
	_check(_one._anchor.distance_to(want) <= 1.0, "%s: reposo %s != %s" % [when, _one._anchor, want])
	_check(_one._rest_center().distance_to(want) <= 1.0, "%s: _rest_center %s != %s" % [when, _one._rest_center(), want])


## Comprueba que el ataque esté a R+ATTACK_GAP a la izquierda del stick y ATTACK_LIFT px arriba.
func _check_cluster(p: Vector2, r: float, when: String) -> void:
	var anchor: Vector2 = _one._anchor
	_check(anchor.distance_to(p) <= 1.0, "%s: el ancla no está en el reposo (%s vs %s)" % [when, anchor, p])
	var a: Vector2 = _attack.hit_center()
	_check(absf(a.x - (anchor.x - r - OneHandControls.ATTACK_GAP * _one.settings.controls_scale)) <= 1.0, "%s: ataque no está a R+GAP a la izquierda (x=%.1f)" % [when, a.x])
	_check(absf(a.y - (anchor.y - OneHandControls.ATTACK_LIFT * _one.settings.controls_scale)) <= 1.0, "%s: ataque no está ATTACK_LIFT arriba del centro (y=%.1f)" % [when, a.y])
	_check(absf(_stone.hit_center().x - a.x) <= 1.0, "%s: la piedra no está centrada sobre el ataque" % when)


func _check_inside(rect: Rect2, r: float, when: String) -> void:
	var anchor: Vector2 = _one._anchor
	var stick: Rect2 = Rect2(anchor - Vector2(r, r), Vector2(r, r) * 2.0)
	for item: Array in [["stick", stick], ["ataque", Rect2(_attack.global_position, _attack.size)], ["piedra", Rect2(_stone.global_position, _stone.size)]]:
		var box: Rect2 = item[1]
		_check(rect.grow(0.5).encloses(box), "%s: %s se sale del control (%s en %s)" % [when, item[0], box, rect])


func _to_screen(pos: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * pos


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e: InputEventScreenTouch = InputEventScreenTouch.new()
	e.index = index
	e.position = _to_screen(pos)
	e.pressed = pressed
	Input.parse_input_event(e)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame
