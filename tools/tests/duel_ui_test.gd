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
	await _check_grid_arc(ui, host)
	# Con neutral (canciones) vuelve la cuadrícula de botones y el arco se oculta.
	ui.left_handed = false
	ui.apply_hand()
	ui.show_grid(DuelUI.Rows.BOTH, false, false, true)
	await _wait(0.1)
	_check(not ui.arc_menu().visible, "el arco sigue visible tras show_grid neutral")
	_check(ui.button_for(&"cell", 0) != null, "no volvió la cuadrícula")
	# Y las celdas son rectas (sin inclinación).
	var cell_box: StyleBoxFlat = ui.button_for(&"cell", 0).get_theme_stylebox("normal") as StyleBoxFlat
	_check(cell_box.skew == Vector2.ZERO, "las celdas no deberían estar inclinadas")
	await _check_hud(ui, host)
	await _check_rival(ui, host)


## Atacar/Bloquear en el arco: 6 sectores + centro (Volver) + franja (Terminar).
func _check_grid_arc(ui: DuelUI, host: Control) -> void:
	for left: bool in [false, true]:
		ui.left_handed = left
		ui.apply_hand()
		var tag: String = "zurdo" if left else "diestro"
		ui.show_grid(DuelUI.Rows.BOTH, true, true)
		await _wait(0.6)
		var arc: ArcMenu = ui.arc_menu()
		_check(arc.visible, "%s: el arco no se ve en show_grid" % tag)
		_check(arc.entry_count() == 8, "%s: el arco de la cuadrícula tiene %d entradas" % [tag, arc.entry_count()])
		_check(not ui.player_hud().compact, "%s: el HUD debería estar completo con show_grid" % tag)
		_check(ui.player_hud().strip, "%s: la base debería extenderse con la franja" % tag)
		for key: String in ["back:0", "end:0", "cell:0", "cell:3"]:
			var b: Button = ui.button_for(StringName(key.get_slice(":", 0)), int(key.get_slice(":", 1)))
			_check(b == null or not b.is_visible_in_tree(), "%s: el botón viejo %s se ve" % [tag, key])
		var pivot: Vector2 = arc.get_global_transform() * arc.pivot()
		var kinds: Array = [[&"cell", 0], [&"cell", 1], [&"cell", 2], [&"cell", 3], [&"cell", 4], [&"cell", 5], [&"back", 0], [&"end", 0]]
		for ev: Array in kinds:
			var pt: Vector2 = ui.point_for(ev[0], ev[1])
			_check(Rect2(Vector2.ZERO, host.size).has_point(pt), "%s: %s cae fuera de la pantalla %s" % [tag, ev, pt])
			_events.clear()
			await _tap(pt)
			_check(_events == [ev], "%s: tocar %s emitió %s" % [tag, ev, _events])
		# izq queda a la izquierda de der en pantalla (bloquear y atacar).
		for base: int in [0, 3]:
			var xl: float = ui.point_for(&"cell", base).x
			var xc: float = ui.point_for(&"cell", base + 1).x
			var xr: float = ui.point_for(&"cell", base + 2).x
			_check(xl < xc and xc < xr, "%s: orden izq/centro/der en pantalla (%s, %s, %s)" % [tag, xl, xc, xr])
		# Atacar (anillo interior) más cerca del pivote que Bloquear.
		_check(ui.point_for(&"cell", 4).distance_to(pivot) < ui.point_for(&"cell", 1).distance_to(pivot), "%s: atacar no está en el anillo interior" % tag)
		# Fila apagada: tocar los ataques no emite; bloquear sí. Sin volver a desplegar.
		ui.set_rows(DuelUI.Rows.TOP)
		await _wait(0.05)
		for cell: int in [3, 4, 5]:
			_events.clear()
			await _tap(ui.point_for(&"cell", cell))
			_check(_events.is_empty(), "%s: el ataque %d apagado emitió %s" % [tag, cell, _events])
		_events.clear()
		await _tap(ui.point_for(&"cell", 1))
		_check(_events == [[&"cell", 1]], "%s: bloquear con TOP emitió %s" % [tag, _events])
		ui.set_rows(DuelUI.Rows.BOTTOM)
		_events.clear()
		await _tap(ui.point_for(&"cell", 4))
		_check(_events == [[&"cell", 4]], "%s: atacar con BOTTOM emitió %s" % [tag, _events])
		# mark no rompe nada.
		ui.mark(&"cell", 4)
		ui.mark(&"end", 0)
		# Sin back/end: no hay centro ni franja y el HUD no extiende la base.
		ui.show_grid(DuelUI.Rows.BOTH, false, false)
		await _wait(0.4)
		_check(arc.entry_count() == 6, "%s: sin back/end debería haber 6 entradas (%d)" % [tag, arc.entry_count()])
		_check(not ui.player_hud().strip, "%s: la base no debería extenderse sin franja" % tag)
		_events.clear()
		await _tap(pivot + Vector2(-60.0 if not left else 60.0, -60.0))
		_check(_events.is_empty(), "%s: el centro sin Volver emitió %s" % [tag, _events])
		ui.show_grid(DuelUI.Rows.BOTH, true, false)
		await _wait(0.4)
		_check(arc.entry_count() == 7, "%s: solo back debería dar 7 entradas (%d)" % [tag, arc.entry_count()])
		ui.set_back_visible(false)
		_check(arc.entry_count() == 6, "%s: set_back_visible(false) no quitó el centro" % tag)
		# Volver al menú restaura el arco normal y el HUD sin franja.
		ui.show_menu("fácil")
		await _wait(0.3)
		_check(arc.entry_count() == 4 and not ui.player_hud().strip, "%s: show_menu no restauró el arco" % tag)
		_events.clear()
		await _tap(ui.point_for(&"menu", 1))
		_check(_events == [[&"menu", 1]], "%s: point_for(menu) emitió %s" % [tag, _events])


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
		for state: String in ["menu", "grid", "grid_util", "neutral", "spells", "items"]:
			match state:
				"menu": ui.show_menu("fácil")
				"grid": ui.show_grid(DuelUI.Rows.BOTH, false, false)
				"grid_util": ui.show_grid(DuelUI.Rows.BOTH, true, true)
				"neutral": ui.show_grid(DuelUI.Rows.BOTH, true, true, true)
				"spells": ui.show_spells(spells, 20)
				"items": ui.show_items(items)
			await _wait(0.4)
			var where: String = "%s/%s" % [tag, state]
			_check(hud.is_visible_in_tree(), "%s: el HUD no se ve" % where)
			_check(hud.get_global_rect().encloses(Rect2(Vector2.ZERO, host.size)), "%s: el HUD no cubre la pantalla" % where)
			var arc: ArcMenu = ui.arc_menu()
			var arc_pivot: Vector2 = arc.get_global_transform() * arc.pivot()
			var hp: Vector2 = hud.get_global_transform() * hud.pivot()
			if state in ["menu", "grid", "grid_util"]:
				_check(not hud.compact, "%s: el HUD debería estar en modo completo" % where)
				_check(hp.is_equal_approx(arc_pivot), "%s: el pivote del HUD %s no coincide con el del arco %s" % [where, hp, arc_pivot])
				var want_r: float = 506.0 if state == "grid_util" else 462.0
				_check(is_equal_approx(hud.dial_radius(), want_r), "%s: radio del HUD completo %s" % [where, hud.dial_radius()])
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
	# Habla `Nombre: "texto"`: globo sin prefijo ni comillas; la lectura va al dial.
	ui.say("Lobo: \"Hola\"\n◆ Piedra: fuerte.")
	_check(ui.speech_text() == "Hola", "el globo dice '%s'" % ui.speech_text())
	_check(ui.narration_text() == "", "no debería haber narración: '%s'" % ui.narration_text())
	_check(d.reading_text == "◆ Piedra: fuerte.", "la lectura del dial: '%s'" % d.reading_text)
	_check(ui._bubble.visible, "el globo debería verse")
	var box: Rect2 = ui._bubble.box_rect()
	_check(absf(box.get_center().x - host.size.x * 0.5) < 1.0, "el globo no está centrado %s" % box)
	_check(box.position.y >= d.dial_radius(), "el globo tapa el dial %s" % box)
	# La lectura va a la derecha de la base, centrada en el eje del dial.
	var rr: Rect2 = d.reading_rect()
	_check(rr.position.x >= 236.0 + 12.0 - 0.5 and rr.end.x <= host.size.x - 16.0 + 0.5, "lectura fuera de su zona %s" % rr)
	_check(absf(rr.get_center().y - d.axis_y()) < 1.0, "la lectura no está en el eje del dial %s vs %s" % [rr, d.axis_y()])
	# Narración: sin globo, mismo lugar.
	ui.say("El carroñero chilla.\n◆ Piedra: débil.")
	_check(ui.speech_text() == "", "la narración no debería ir al globo: '%s'" % ui.speech_text())
	_check(ui.narration_text() == "El carroñero chilla.", "narración: '%s'" % ui.narration_text())
	_check(d.reading_text == "◆ Piedra: débil.", "la lectura de la narración: '%s'" % d.reading_text)
	_check(ui._bubble.visible and ui._bubble.box_rect() == Rect2(), "narración sin caja de globo")
	var nr: Rect2 = ui._bubble.narration_rect()
	_check(absf(nr.get_center().x - host.size.x * 0.5) < 1.0 and nr.position.y >= d.dial_radius(), "la narración está mal puesta %s" % nr)
	ui.say("El gólem cruje: se prepara.")
	_check(ui.narration_text() == "El gólem cruje: se prepara." and ui.speech_text() == "", "una línea con ':' sin comillas es narración")
	ui.say("◆ Piedra: sola.")
	_check(ui.speech_text() == "" and ui.narration_text() == "" and not ui._bubble.visible, "una lectura sola no debería dejar globo ni narración")
	ui.say("Eco sin prefijo")
	_check(ui.speech_text() == "" and ui.narration_text() == "Eco sin prefijo", "sin forma de habla es narración")
	ui.say("")
	_check(not ui._bubble.visible and ui.speech_text() == "" and ui.narration_text() == "", "say('') debería ocultar todo")
	ui.status("Cargando…")
	_check(d.status_text == "Cargando…", "el estado no llegó al dial")
	ui.status("")
	await _check_prompt(ui, host)
	await _check_hp_number(ui, host)
	# Vida: lo vacío crece desde arriba (el relleno queda anclado abajo).
	ui.left_handed = false
	ui.apply_hand()


## El aviso: encima del arco en el menú; encima de la fila de botones (o de la
## cuadrícula) en modo compacto. No cruza botones, globo ni la base del jugador.
func _check_prompt(ui: DuelUI, host: Control) -> void:
	ui.set_rival("Lobo", 30, 40)
	ui.say("Lobo: \"La última vez cubriste a la izquierda, ¿te acuerdas?\"")
	ui.prompt("Tu turno. Elige qué hacer con tu piedra y tu espada.")
	for left: bool in [false, true]:
		ui.left_handed = left
		ui.apply_hand()
		for state: String in ["menu", "grid_arc", "grid_arc_bare", "grid_util", "grid_bare"]:
			match state:
				"menu": ui.show_menu("fácil")
				"grid_arc": ui.show_grid(DuelUI.Rows.BOTH, true, true)
				"grid_arc_bare": ui.show_grid(DuelUI.Rows.BOTH, false, false)
				"grid_util": ui.show_grid(DuelUI.Rows.BOTH, true, true, true)
				"grid_bare": ui.show_grid(DuelUI.Rows.BOTH, false, false, true)
			await _wait(0.3)
			var where: String = "%s/%s" % ["zurdo" if left else "diestro", state]
			var pl: Label = ui.prompt_label()
			var pr: Rect2 = pl.get_global_rect()
			_check(Rect2(Vector2.ZERO, host.size).encloses(pr), "%s: el aviso se sale de la pantalla %s" % [where, pr])
			_check(pr.size.x <= 440.0 + 0.5, "%s: el aviso es muy ancho %s" % [where, pr])
			_check(pl.get_theme_font_size("font_size") == 22, "%s: tamaño del aviso" % where)
			_check(pl.get_line_count() <= 2 or pl.max_lines_visible == 2, "%s: más de 2 renglones" % where)
			var bubble: SpeechBubble = ui.bubble()
			var bb: Rect2 = bubble.box_rect()
			bb = bb.grow_individual(0.0, 0.0, 0.0, SpeechBubble.TAIL_H)
			_check(not pr.intersects(bb), "%s: el aviso cruza el globo %s vs %s" % [where, pr, bb])
			for b: Button in [ui._back_button, ui._end_button]:
				if b.is_visible_in_tree():
					_check(not pr.intersects(b.get_global_rect()), "%s: el aviso cruza un botón %s" % [where, b.get_global_rect()])
			for key: String in ["cell:0", "cell:1", "cell:2", "cell:3", "cell:4", "cell:5"]:
				var cb: Button = ui.button_for(StringName(key.get_slice(":", 0)), int(key.get_slice(":", 1)))
				if cb != null and cb.is_visible_in_tree():
					_check(not pr.intersects(cb.get_global_rect()), "%s: el aviso cruza %s" % [where, key])
			var hand_side: bool = pr.get_center().x > host.size.x * 0.5
			_check(hand_side != left, "%s: el aviso no está del lado de la mano %s" % [where, pr])
			if state in ["menu", "grid_arc", "grid_arc_bare"]:
				var hud: PlayerHud = ui.player_hud()
				var hp: Vector2 = hud.get_global_transform() * hud.pivot()
				var reach: float = 506.0 if state == "grid_arc" else 462.0
				var top: float = hp.y - reach
				_check(absf(pr.end.y - (top - 12.0)) < 1.0, "%s: el aviso debería terminar 12 px sobre la base (%s vs %s)" % [where, pr.end.y, top - 12.0])
				# Su caja no toca el arco de la base en ningún punto.
				var far: Vector2 = Vector2(pr.position.x if not left else pr.end.x, pr.end.y)
				_check(far.distance_to(hp) > reach, "%s: el aviso toca la base %s" % [where, far])
			else:
				var row_top: float = ui._util_row.global_position.y if state == "grid_util" else ui._cluster.global_position.y
				_check(pr.end.y <= row_top - 11.0, "%s: el aviso no está sobre los botones (%s vs %s)" % [where, pr.end.y, row_top])
				_check(pr.end.y >= row_top - 14.0, "%s: el aviso está lejos de los botones (%s vs %s)" % [where, pr.end.y, row_top])
	ui.say("")


## Número de PV del jugador: recto, dentro de pantalla, sin tocar la barra.
func _check_hp_number(ui: DuelUI, host: Control) -> void:
	ui.set_stats(100, 100, 3, 9, 5, 12)
	for left: bool in [false, true]:
		ui.left_handed = left
		ui.apply_hand()
		for compact: bool in [false, true]:
			if compact:
				ui.show_grid(DuelUI.Rows.BOTH, false, false, true)
			else:
				ui.show_menu("fácil")
			await _wait(0.3)
			var hud: PlayerHud = ui.player_hud()
			var r: Rect2 = hud.get_global_transform() * hud.number_rect()
			var where: String = "%s/%s" % ["zurdo" if left else "diestro", "compacto" if compact else "completo"]
			_check(Rect2(Vector2.ZERO, host.size).encloses(r), "%s: el número de PV se sale de la pantalla %s" % [where, r])
			if not compact:
				var hp: Vector2 = hud.get_global_transform() * hud.pivot()
				# Los 4 vértices quedan entre el botón central (118) y la barra (184).
				for c: Vector2 in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
					_check(c.distance_to(hp) < 184.0, "%s: el número de PV toca la barra %s" % [where, r])
					_check(c.distance_to(hp) > 118.0, "%s: el número de PV toca el botón central %s" % [where, r])
				_check(r.end.y <= hp.y + 12.0, "%s: el número de PV baja del margen %s" % [where, r])
				# En el mismo lugar con el arco de atacar/bloquear.
				ui.show_grid(DuelUI.Rows.BOTH, true, true)
				await _wait(0.2)
				var r2: Rect2 = hud.get_global_transform() * hud.number_rect()
				_check(r2.is_equal_approx(r), "%s: el número de PV saltó entre menú y cuadrícula" % where)


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
