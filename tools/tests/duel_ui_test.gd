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
		var gap_pt: Vector2 = pivot + Vector2(-cos(deg_to_rad(225.0)) * -1.0 * side, sin(deg_to_rad(225.0))) * 280.0
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
	await _check_hud(ui, host)
	await _check_rival(ui, host)


## El HUD del jugador: completo (pivote del arco) con el menú, y compacto
## (cuarto de disco en la esquina contraria) cuando hay cuadrícula, sin cruzar botones.
func _check_hud(ui: DuelUI, host: Control) -> void:
	var spells: Array = [
		{"name": "Trueno", "cost": 4}, {"name": "Egida", "cost": 3}, {"name": "Cura", "cost": 5},
		{"name": "Rayo", "cost": 6}, {"name": "Hielo", "cost": 2}]
	var items: Array = [
		{"name": "Pocion", "desc": "Cura 30", "count": 2}, {"name": "Ether", "desc": "+4 PM", "count": 1},
		{"name": "Humo", "desc": "Huir", "count": 0}, {"name": "Piedra", "desc": "Lanza", "count": 3}]
	ui.set_stats(80, 100, 3, 9, 5, 12)
	for left: bool in [false, true]:
		ui.left_handed = left
		ui.apply_hand()
		var tag: String = "zurdo" if left else "diestro"
		var hud: PlayerHud = ui.player_hud()
		for state: String in ["menu", "grid", "grid_util", "spells", "items"]:
			match state:
				"menu": ui.show_menu("fácil")
				"grid": ui.show_grid(DuelUI.Rows.BOTH, false, false)
				"grid_util": ui.show_grid(DuelUI.Rows.BOTH, true, true)
				"spells": ui.show_spells(spells, 20)
				"items": ui.show_items(items)
			await _wait(0.4)
			var where: String = "%s/%s" % [tag, state]
			_check(hud.is_visible_in_tree(), "%s: el HUD no se ve" % where)
			_check(hud.get_global_rect().encloses(Rect2(Vector2.ZERO, host.size)), "%s: el HUD no cubre la pantalla" % where)
			var arc: ArcMenu = ui.arc_menu()
			var arc_pivot: Vector2 = arc.get_global_transform() * arc.pivot()
			var hp: Vector2 = hud.get_global_transform() * hud.pivot()
			if state == "menu":
				_check(not hud.compact, "%s: el HUD debería estar en modo completo" % where)
				_check(hp.is_equal_approx(arc_pivot), "%s: el pivote del HUD %s no coincide con el del arco %s" % [where, hp, arc_pivot])
				_check(is_equal_approx(hud.dial_radius(), 462.0), "%s: radio del HUD completo %s" % [where, hud.dial_radius()])
				continue
			_check(hud.compact, "%s: el HUD debería estar en modo compacto" % where)
			# Esquina contraria a la mano, pegada abajo.
			var want_x: float = host.size.x if left else 0.0
			_check(is_equal_approx(hp.x, 0.0 if not left else host.size.x), "%s: el pivote del HUD no está en la esquina contraria %s" % [where, hp])
			_check(hp.x != arc_pivot.x and (hp.x == 0.0 or hp.x == host.size.x), "%s: pivote compacto en x=%s (mano en %s)" % [where, hp.x, arc_pivot.x])
			_check(not is_equal_approx(hp.x, arc_pivot.x), "%s: el HUD compacto está en la esquina de la mano" % where)
			_check(hp.y > host.size.y - 60.0, "%s: el HUD no está pegado abajo %s" % [where, hp])
			_check(is_equal_approx(hud.dial_radius(), 214.0), "%s: el radio del cuarto de disco es %s" % [where, hud.dial_radius()])
			# Botones visibles: el punto más cercano de cada uno al pivote queda fuera del cuarto de disco.
			var rects: Array[Rect2] = []
			for key: String in ["back:0", "end:0", "cell:0", "cell:1", "cell:2", "cell:3", "cell:4", "cell:5",
					"spell:0", "spell:1", "spell:2", "spell:3", "spell:4", "item:0", "item:1", "item:2", "item:3"]:
				var b: Button = ui.button_for(StringName(key.get_slice(":", 0)), int(key.get_slice(":", 1)))
				if b != null and b.is_visible_in_tree():
					rects.append(b.get_global_rect())
			for br: Rect2 in rects:
				var near: Vector2 = Vector2(clampf(hp.x, br.position.x, br.end.x), clampf(hp.y, br.position.y, br.end.y))
				_check(near.distance_to(hp) > 214.0, "%s: el HUD compacto cruza un botón %s (a %.0f px)" % [where, br, near.distance_to(hp)])
			_check(rects.size() >= 2, "%s: no se encontraron botones para comparar" % where)
			# Los segmentos caen dentro de x 0..214 (o el espejo) y de la pantalla.
			var seg: Rect2 = hud.segment_rect_global(&"pa", 0)
			_check(Rect2(Vector2.ZERO, host.size).encloses(seg), "%s: el segmento de PA se sale de la pantalla %s" % [where, seg])
			var limit_ok: bool = seg.end.x <= 214.0 if not left else seg.position.x >= host.size.x - 214.0
			_check(limit_ok, "%s: el segmento de PA pasa de 214 px %s" % [where, seg])
			_check(want_x == hp.x, "%s: pivote compacto en x=%s, debía ser %s" % [where, hp.x, want_x])
	# 9 PA máximos con 3 llenos: 9 pips, 3 encendidos.
	ui.left_handed = false
	ui.apply_hand()
	ui.set_stats(60, 100, 3, 9, 7, 12)
	_check(ui.player_hud().pip_count(&"pa") == 9, "el HUD debería tener 9 pips de PA")
	_check(ui.player_hud().lit_count(&"pa") == 3, "el HUD debería tener 3 PA encendidos")
	_check(ui.player_hud().pip_count(&"pm") == 12 and ui.player_hud().lit_count(&"pm") == 7, "pips de PM mal")
	_check(ui.player_hud().hp_value() == 60, "el HUD no guardó los PV")
	ui.set_stats(40, 100, 1, 9, 7, 12)
	await _wait(0.5)  # las animaciones de gasto/destello terminan solas
	_check(ui.player_hud().lit_count(&"pa") == 1, "el HUD no bajó los PA")
	_check(not ui.player_hud().is_processing(), "el HUD sigue animando de más")


## La zona del rival: dial en la esquina de arriba contraria a la mano, vida,
## nombre ajustado al arco y globo de diálogo.
func _check_rival(ui: DuelUI, host: Control) -> void:
	for left: bool in [false, true]:
		ui.left_handed = left
		ui.apply_hand()
		var tag: String = "zurdo" if left else "diestro"
		var dial: RivalDial = ui.rival_dial()
		await _wait(0.1)
		var p: Vector2 = dial.get_global_transform() * dial.pivot()
		_check(is_equal_approx(p.x, host.size.x if left else 0.0), "%s: el dial del rival no está en la esquina contraria %s" % [tag, p])
		_check(p.y >= 0.0 and p.y <= 16.0, "%s: el dial del rival no está arriba %s" % [tag, p])
		_check(dial.get_global_rect().encloses(Rect2(Vector2.ZERO, host.size)), "%s: el dial no cubre la pantalla" % tag)
		var arc_pivot: Vector2 = ui.arc_menu().get_global_transform() * ui.arc_menu().pivot()
		_check(not is_equal_approx(p.x, arc_pivot.x), "%s: el dial del rival está del lado de la mano" % tag)
	ui.left_handed = false
	ui.apply_hand()
	var d: RivalDial = ui.rival_dial()
	ui.set_rival("Lobo", 30, 40)
	_check(d.hp_value() == 30 and d.max_hp_value() == 40, "set_rival no actualizó la vida")
	ui.set_rival("Lobo", 12, 40)
	_check(d.hp_value() == 12, "set_rival no bajó la vida")
	await _wait(0.5)
	_check(not d.is_processing(), "el dial sigue animando de más")
	# Nombre: corto = 1 renglón; largo = 2; absurdo = recortado con "…".
	_check(d.name_lines() == PackedStringArray(["LOBO"]), "nombre corto: %s" % d.name_lines())
	_check(d.name_font_size() == 24, "nombre corto debería ir a 24, va a %d" % d.name_font_size())
	ui.set_rival("Lobo de ceniza", 12, 40)
	_check(d.name_lines().size() == 1 and d.name_font_size() >= 16, "'Lobo de ceniza': %s a %d" % [d.name_lines(), d.name_font_size()])
	ui.set_rival("Penitente de hierro de la mina vieja", 12, 40)
	_check(d.name_lines().size() == 2, "nombre largo debería ir en 2 renglones: %s" % d.name_lines())
	_check(not d.name_lines()[0].ends_with("…") and not d.name_lines()[1].ends_with("…"), "nombre largo no debería recortarse: %s" % d.name_lines())
	var absurd: String = ""
	for i: int in 12:
		absurd += "Abcde "
	ui.set_rival(absurd.strip_edges().substr(0, 60), 12, 40)
	_check(d.name_lines().size() <= 2 and d.name_lines()[d.name_lines().size() - 1].ends_with("…"), "nombre absurdo debería recortarse: %s" % d.name_lines())
	ui.set_rival("Lobo de ceniza", 12, 40)
	# Globo: quita el nombre y las comillas; la lectura va al dial.
	ui.say("Lobo de ceniza: \"Hola\"\n◆ Piedra: fuerte.")
	_check(ui.speech_text() == "Hola", "el globo dice '%s'" % ui.speech_text())
	_check(d.reading_text == "◆ Piedra: fuerte.", "la lectura del dial: '%s'" % d.reading_text)
	_check(ui._bubble.visible, "el globo debería verse")
	var box: Rect2 = ui._bubble.box_rect()
	_check(absf(box.get_center().x - host.size.x * 0.5) < 1.0, "el globo no está centrado %s" % box)
	_check(box.position.y >= d.dial_radius(), "el globo tapa el dial %s" % box)
	ui.say("◆ Piedra: sola.")
	_check(ui.speech_text() == "" and not ui._bubble.visible, "una lectura sola no debería dejar globo")
	ui.say("Eco sin prefijo")
	_check(ui.speech_text() == "Eco sin prefijo", "sin prefijo: '%s'" % ui.speech_text())
	ui.say("")
	_check(not ui._bubble.visible and ui.speech_text() == "", "say('') debería ocultar el globo")
	ui.status("Cargando…")
	_check(d.status_text == "Cargando…", "el estado no llegó al dial")
	ui.status("")
	# El aviso queda a la derecha del dial (diestro) y a la izquierda (zurdo).
	ui.prompt("Elige qué hacer")
	for left: bool in [false, true]:
		ui.left_handed = left
		ui.apply_hand()
		var pr: Rect2 = ui._prompt.get_global_rect()
		var dial_rect: Rect2 = Rect2(0.0 if not left else host.size.x - d.dial_radius(), 0.0, d.dial_radius(), d.dial_radius() + 8.0)
		_check(not pr.intersects(dial_rect), "%s: el aviso choca con el dial %s" % ["zurdo" if left else "diestro", pr])
	ui.left_handed = false
	ui.apply_hand()


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
