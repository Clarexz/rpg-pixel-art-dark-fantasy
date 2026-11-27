extends Node
## Prueba de la pantalla del duelo (DuelUI): el menú del turno es un abanico
## diagonal de 4 botones (el grande abajo, pegado a la mano) y se espeja en zurdo.
## Corre en CI con: godot --headless --path . res://tools/tests/duel_ui_test.tscn

var _failures: PackedStringArray = []


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
	await _wait(0.1)
	var bounds: Rect2 = Rect2(Vector2.ZERO, host.size)
	for left: bool in [false, true]:
		ui.left_handed = left
		ui.apply_hand()
		ui.show_menu("difícil")
		await _wait(0.6)
		var tag: String = "zurdo" if left else "diestro"
		var rects: Array[Rect2] = []
		for i: int in 4:
			var b: Button = ui.button_for(&"menu", i)
			_check(b != null, "%s: falta menu:%d" % [tag, i])
			if b == null:
				return
			rects.append(b.get_global_rect())
			_check(bounds.encloses(rects[i]), "%s: menu:%d fuera de la pantalla %s" % [tag, i, rects[i]])
			_check(is_equal_approx(b.modulate.a, 1.0), "%s: menu:%d sin terminar de aparecer" % [tag, i])
		for i: int in 3:
			_check(rects[i].size.y > rects[i + 1].size.y, "%s: la altura no decrece en %d" % [tag, i])
			_check(rects[i].position.y > rects[i + 1].position.y, "%s: menu:%d no está debajo de menu:%d" % [tag, i, i + 1])
		# Distancia entre el borde de la mano y la orilla de la pantalla.
		var gaps: Array[float] = []
		for r: Rect2 in rects:
			gaps.append(host.size.x - r.end.x if not left else r.position.x)
		for i: int in 3:
			_check(gaps[0] < gaps[i + 1], "%s: menu:0 no es el más cercano a la mano" % tag)
		if left:
			_check(rects[0].get_center().x < host.size.x * 0.5, "zurdo: el abanico debería estar a la izquierda")
		else:
			_check(rects[0].get_center().x > host.size.x * 0.5, "diestro: el abanico debería estar a la derecha")
	# Al pedir la cuadrícula el abanico desaparece y vuelven las celdas.
	ui.show_grid(DuelUI.Rows.BOTH, false, false)
	await _wait(0.1)
	_check(ui.button_for(&"menu", 0) == null, "el abanico sigue registrado tras show_grid")
	_check(ui.button_for(&"cell", 0) != null, "no volvió la cuadrícula")


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
