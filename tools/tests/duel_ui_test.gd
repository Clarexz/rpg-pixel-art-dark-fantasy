extends Node
## Prueba de la pantalla del duelo (DuelUI): el menú del turno es un arco de
## 4 sectores alrededor de la esquina de la mano (2 anillos) y se espeja en zurdo.
## Corre en CI con: godot --headless --path . res://tools/tests/duel_ui_test.tscn

var _failures: PackedStringArray = []
var _events: Array = []


func _ready() -> void:
	await _run()
	if _failures.is_empty():
		print("DUEL UI TEST OK")
		get_tree().quit(0)
	else:
		for f: String in _failures:
			printerr("DUEL UI TEST FAIL: ", f)
		get_tree().quit(1)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_failures.append(msg)


func _run() -> void:
	var host: Control = Control.new()
	host.size = Vector2(720, 1280)
	add_child(host)
	var ui: DuelUI = DuelUI.new()
	host.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.show()
	_events.clear()
	ui.event.connect(func(kind: StringName, value: int) -> void: _events.append([kind, value]))
	await _wait(0.1)
	var bounds: Rect2 = Rect2(Vector2.ZERO, host.size)
	for left: bool in [false, true]:
		ui.left_handed = left
		ui.apply_hand()
		ui.show_menu("difícil")
		await _wait(0.6)
		var tag: String = "zurdo" if left else "diestro"
		var arc: ArcMenu = ui.arc_menu()
		_check(arc.visible, "%s: el arco no se ve" % tag)
		_check(arc.entry_count() == 4, "%s: el arco no tiene 4 entradas" % tag)
		var pivot: Vector2 = arc.get_global_transform() * arc.pivot()
		var want_x: float = 0.0 if left else host.size.x
		_check(is_equal_approx(pivot.x, want_x), "%s: el pivote debería estar en x=%s, está en %s" % [tag, want_x, pivot.x])
		_check(pivot.y > host.size.y - 60.0 and pivot.y <= host.size.y, "%s: el pivote no está abajo %s" % [tag, pivot])
		var dist: Array[float] = []
		for i: int in 4:
			var pt: Vector2 = ui.menu_point(i)
			dist.append(pt.distance_to(pivot))
			_check(bounds.has_point(pt), "%s: el centro de menu:%d cae fuera de la pantalla %s" % [tag, i, pt])
		_check(dist[0] < dist[2] and dist[0] < dist[3], "%s: menu:0 no está en el anillo interior" % tag)
		_check(dist[1] < dist[2] and dist[1] < dist[3], "%s: menu:1 no está en el anillo interior" % tag)
		# Tocar el centro de cada sector emite su índice.
		for i: int in 4:
			_events.clear()
			await _tap(ui.menu_point(i))
			_check(_events == [[&"menu", i]], "%s: tocar menu:%d emitió %s" % [tag, i, _events])
		# Un toque en el hueco entre sectores va a un vecino.
		var side: float = -1.0 if left else 1.0
		var gap_pt: Vector2 = pivot + Vector2(-cos(deg_to_rad(230.0)) * -1.0 * side, sin(deg_to_rad(230.0))) * 315.0
		_events.clear()
		await _tap(gap_pt)
		_check(_events.size() == 1 and _events[0][1] in [0, 1], "%s: el hueco entre sectores emitió %s" % [tag, _events])
		# Lejos del arco (cerca del pivote y en el centro de la pantalla): nada.
		for far: Vector2 in [pivot + Vector2(-60.0 * side, -60.0), host.size * Vector2(0.5, 0.3), pivot + Vector2(-700.0 * side, -20.0)]:
			_events.clear()
			await _tap(far)
			_check(_events.is_empty(), "%s: un toque lejos del arco en %s emitió %s" % [tag, far, _events])
	# Al pedir la cuadrícula el arco desaparece y vuelven las celdas.
	ui.show_grid(DuelUI.Rows.BOTH, false, false)
	await _wait(0.1)
	_check(not ui.arc_menu().visible, "el arco sigue visible tras show_grid")
	_check(ui.button_for(&"cell", 0) != null, "no volvió la cuadrícula")
	# Y las celdas son rectas (sin inclinación).
	var cell_box: StyleBoxFlat = ui.button_for(&"cell", 0).get_theme_stylebox("normal") as StyleBoxFlat
	_check(cell_box.skew == Vector2.ZERO, "las celdas no deberían estar inclinadas")


## Toca un punto global (como el pulgar): ScreenTouch abajo y arriba.
func _tap(pos: Vector2) -> void:
	await _wait(0.2)  # pasa el candado de SWAP_LOCK_MS
	var screen: Vector2 = get_viewport().get_screen_transform() * pos
	for pressed: bool in [true, false]:
		var e: InputEventScreenTouch = InputEventScreenTouch.new()
		e.position = screen
		e.pressed = pressed
		Input.parse_input_event(e)
		await get_tree().process_frame
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
