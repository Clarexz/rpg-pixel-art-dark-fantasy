extends Node
## Prueba del conjunto de exploración a una mano: el stick flotante y los
## botones ATACAR / PIEDRA se mueven juntos, se quedan donde soltaste el
## pulgar, no se salen de la pantalla y se reflejan en modo zurdo.
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
	var r: float = _one.settings.joystick_radius

	# 1) Toque del stick en P y soltar: el conjunto se muda a P y se queda.
	print("Paso 1: el conjunto sigue al pulgar y se queda al soltar.")
	var p: Vector2 = Vector2(rect.get_center().x + 60.0, rect.end.y - 250.0)
	_touch(0, p, true)
	await _frames(2)
	_check_cluster(p, r, "con el dedo puesto")
	_touch(0, p, false)
	await _frames(5)
	_check_cluster(p, r, "después de soltar")
	_check(_stone.hit_center().y < _attack.hit_center().y, "la piedra no está arriba del ataque")

	# 2) Tocar ATACAR no mueve el conjunto.
	print("Paso 2: tocar ATACAR no mueve el conjunto.")
	var tap: Vector2 = _attack.hit_center()
	_touch(1, tap, true)
	await _frames(2)
	_touch(1, tap, false)
	await _frames(2)
	_check_cluster(p, r, "tras tocar ATACAR")

	# 3) Cerca del borde izquierdo: todo cabe en el control.
	print("Paso 3: junto al borde izquierdo todo cabe en pantalla.")
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

	# 4) Zurdo: los botones pasan a la derecha del stick.
	print("Paso 4: en modo zurdo el ataque queda a la derecha del stick.")
	_one.settings.left_handed = true
	_world.apply_mode()
	await _frames(3)
	_touch(0, p, true)
	await _frames(2)
	_touch(0, p, false)
	await _frames(2)
	var anchor: Vector2 = _one._anchor
	_check(absf(_attack.hit_center().x - (anchor.x + r + OneHandControls.ATTACK_GAP)) <= 1.0, "zurdo: ataque no está a R+80 a la derecha (x=%.1f, ancla=%.1f)" % [_attack.hit_center().x, anchor.x])
	_check(absf(_stone.hit_center().x - _attack.hit_center().x) <= 1.0, "zurdo: la piedra no está sobre el ataque")
	_check_inside(rect, r, "zurdo")
	_one.settings.left_handed = false
	_world.apply_mode()
	await _frames(3)


## Comprueba que el ataque esté a R+ATTACK_GAP a la izquierda del stick y ATTACK_LIFT px arriba.
func _check_cluster(p: Vector2, r: float, when: String) -> void:
	var anchor: Vector2 = _one._anchor
	_check(anchor.distance_to(p) <= 1.0, "%s: el ancla no está en el toque (%s vs %s)" % [when, anchor, p])
	var a: Vector2 = _attack.hit_center()
	_check(absf(a.x - (anchor.x - r - OneHandControls.ATTACK_GAP)) <= 1.0, "%s: ataque no está a R+80 a la izquierda (x=%.1f)" % [when, a.x])
	_check(absf(a.y - (anchor.y - OneHandControls.ATTACK_LIFT)) <= 1.0, "%s: ataque no está 40 px arriba del centro (y=%.1f)" % [when, a.y])
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
