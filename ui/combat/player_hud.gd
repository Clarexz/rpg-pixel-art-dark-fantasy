class_name PlayerHud
extends Control
## Estado del jugador en combate, dibujado por código y recto (sin diagonales):
## PV con número grande y barra, y debajo los PA (círculos dorados) y los PM
## (rombos morados), uno por punto máximo: lleno = disponible, hueco = gastado.
##
## Dónde va (lo coloca DuelUI): en la esquina inferior del lado CONTRARIO a la
## mano, dentro del hueco que deja el arco del menú. El arco sale del pivote
## (esquina inferior de la mano) con radio exterior 520 px; en 720 de ancho el
## borde más cercano del HUD (su esquina inferior interna) queda a 532 px del
## pivote, así que nunca lo toca. La cuadrícula/botones útiles ocupan como
## mucho 480 px pegados a la orilla de la mano (x 224..704), y el HUD llega
## hasta x 188: no se cruzan en ningún estado, y como el HUD no se mueve no
## hace falta recalcular nada al cambiar de menú.

## Tamaño fijo del panel y su separación de la orilla (la zona segura de abajo
## es la misma que la del arco y los botones).
const HUD_SIZE: Vector2 = Vector2(182.0, 202.0)
const EDGE_MARGIN: float = 6.0
const BOTTOM_MARGIN: float = 24.0

const PAD: float = 8.0
const PIP_R: float = 9.0
const PIP_GAP: float = 3.0
const PIP_COLS: int = 6
const ROW_PITCH: float = 22.0
const HP_BAR_H: float = 20.0
const NUM_SIZE: int = 40
const LABEL_SIZE: int = 20
const LABEL_W: float = 34.0

const COLOR_HP: Color = Color(0.8, 0.2, 0.22)
const COLOR_PA: Color = Color(0.91, 0.72, 0.28)
const COLOR_PM: Color = Color(0.42, 0.35, 0.8)
const COLOR_EMPTY: Color = Color(0.12, 0.1, 0.15)

const HP_FLASH_TIME: float = 0.35
const PIP_ANIM_TIME: float = 0.3

var left_handed: bool = false:
	set(value):
		left_handed = value
		place()

var _hp: int = 0
var _max_hp: int = 1
var _pa: int = 0
var _max_pa: int = 0
var _pm: int = 0
var _max_pm: int = 0
var _started: bool = false
var _hp_flash: float = 0.0
## Tiempo restante de la animación de cada pip (1 → 0) y su sentido:
## +1 = se acaba de recuperar, -1 = se acaba de gastar.
var _pip_t: Dictionary = {&"pa": [], &"pm": []}
var _pip_dir: Dictionary = {&"pa": [], &"pm": []}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = HUD_SIZE
	set_process(false)
	place()


## Esquina inferior del lado contrario a la mano (diestro: abajo-izquierda).
func place() -> void:
	if left_handed:
		set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		offset_left = -(EDGE_MARGIN + HUD_SIZE.x)
		offset_right = -EDGE_MARGIN
	else:
		set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		offset_left = EDGE_MARGIN
		offset_right = EDGE_MARGIN + HUD_SIZE.x
	offset_top = -(BOTTOM_MARGIN + HUD_SIZE.y)
	offset_bottom = -BOTTOM_MARGIN
	queue_redraw()


func set_stats(hp: int, max_hp: int, pa: int, max_pa: int, pm: int, max_pm: int) -> void:
	if _started:
		if hp < _hp:
			_hp_flash = 1.0
		_note_change(&"pa", _pa, pa, max_pa)
		_note_change(&"pm", _pm, pm, max_pm)
	else:
		_pip_t[&"pa"] = _zeros(max_pa)
		_pip_dir[&"pa"] = _zeros(max_pa)
		_pip_t[&"pm"] = _zeros(max_pm)
		_pip_dir[&"pm"] = _zeros(max_pm)
	_started = true
	_hp = hp
	_max_hp = maxi(max_hp, 1)
	_pa = pa
	_max_pa = max_pa
	_pm = pm
	_max_pm = max_pm
	_wake()
	queue_redraw()


## Para las pruebas: cuántos pips hay de "pa" o "pm" y cuántos están llenos.
func pip_count(kind: StringName) -> int:
	return _max_pa if kind == &"pa" else _max_pm


func lit_count(kind: StringName) -> int:
	return clampi(_pa if kind == &"pa" else _pm, 0, pip_count(kind))


func hp_value() -> int:
	return _hp


func _zeros(n: int) -> Array:
	var a: Array = []
	a.resize(maxi(n, 0))
	a.fill(0.0)
	return a


## Marca qué pips cambiaron para que hagan "pop" o se enciendan.
func _note_change(kind: StringName, before: int, after: int, new_max: int) -> void:
	var t: Array = _pip_t[kind]
	var dir: Array = _pip_dir[kind]
	while t.size() < new_max:
		t.append(0.0)
		dir.append(0.0)
	while t.size() > new_max:
		t.pop_back()
		dir.pop_back()
	var lo: int = clampi(mini(before, after), 0, new_max)
	var hi: int = clampi(maxi(before, after), 0, new_max)
	for i: int in range(lo, hi):
		t[i] = 1.0
		dir[i] = -1.0 if after < before else 1.0


func _wake() -> void:
	if not is_processing():
		set_process(true)


func _process(delta: float) -> void:
	var busy: bool = false
	if _hp_flash > 0.0:
		_hp_flash = maxf(_hp_flash - delta / HP_FLASH_TIME, 0.0)
		busy = busy or _hp_flash > 0.0
	for kind: StringName in [&"pa", &"pm"]:
		var t: Array = _pip_t[kind]
		for i: int in t.size():
			if t[i] > 0.0:
				t[i] = maxf(t[i] - delta / PIP_ANIM_TIME, 0.0)
				busy = busy or t[i] > 0.0
	queue_redraw()
	if not busy:
		set_process(false)


func _draw() -> void:
	var font: Font = CombatStyle.title_font()
	# Fondo semitransparente con borde oscuro de 4 px, esquinas rectas.
	draw_rect(Rect2(Vector2.ZERO, size), CombatStyle.PANEL)
	draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), CombatStyle.OUTLINE, false, 4.0)
	var inner_w: float = size.x - PAD * 2.0
	var y: float = PAD + 2.0
	# PV: etiqueta chica + número grande con contorno oscuro.
	_text(font, "PV", Vector2(PAD + 2.0, y + 34.0), LABEL_SIZE, Color(1, 1, 1, 0.75), 4)
	_text(font, str(_hp), Vector2(PAD + LABEL_W + 4.0, y + 38.0), NUM_SIZE, Color.WHITE, 8)
	y += 46.0
	# Barra de PV: recta, contorno oscuro, destello blanco al recibir daño.
	var bar: Rect2 = Rect2(PAD, y, inner_w, HP_BAR_H)
	draw_rect(bar, COLOR_EMPTY)
	var frac: float = clampf(float(_hp) / float(_max_hp), 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), COLOR_HP.lerp(Color.WHITE, _hp_flash))
	draw_rect(bar.grow(-2.0), CombatStyle.OUTLINE, false, 4.0)
	y += HP_BAR_H + 12.0
	y = _pip_rows(font, &"pa", "PA", y)
	y += 8.0
	_pip_rows(font, &"pm", "PM", y)


## Filas de pips con su etiqueta; devuelve la y donde terminan.
func _pip_rows(font: Font, kind: StringName, label: String, y: float) -> float:
	var total: int = pip_count(kind)
	var lit: int = lit_count(kind)
	var color: Color = COLOR_PA if kind == &"pa" else COLOR_PM
	var t: Array = _pip_t[kind]
	var dir: Array = _pip_dir[kind]
	_text(font, label, Vector2(PAD + 2.0, y + 17.0), LABEL_SIZE - 2, Color(1, 1, 1, 0.75), 4)
	var x0: float = PAD + LABEL_W + 4.0 + PIP_R
	var step: float = PIP_R * 2.0 + PIP_GAP
	for i: int in total:
		var c: Vector2 = Vector2(x0 + (i % PIP_COLS) * step, y + PIP_R + 1.0 + (i / PIP_COLS) * ROW_PITCH)
		var anim: float = t[i] if i < t.size() else 0.0
		var d: float = dir[i] if i < dir.size() else 0.0
		var filled: bool = i < lit or (anim > 0.0 and d < 0.0)
		var scale: float = 1.0
		var fill: Color = color if filled else COLOR_EMPTY
		if anim > 0.0:
			# Gastado: crece y se vuelve blanco mientras se apaga. Recuperado: se enciende con destello.
			scale = 1.0 + (0.5 if d < 0.0 else 0.35) * anim
			if filled:
				fill = color.lerp(Color.WHITE, anim)
		_pip(kind, c, PIP_R * scale, fill, color, filled)
	var rows: int = maxi(ceili(float(total) / PIP_COLS), 1)
	return y + rows * ROW_PITCH


func _pip(kind: StringName, c: Vector2, r: float, fill: Color, edge: Color, filled: bool) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	if kind == &"pa":
		var n: int = 20
		for k: int in n:
			var a: float = TAU * k / n
			pts.append(c + Vector2(cos(a), sin(a)) * r)
	else:
		# Rombo: cuatro vértices sobre los ejes (forma propia de los PM).
		var rr: float = r * 1.2
		pts = PackedVector2Array([c + Vector2(0, -rr), c + Vector2(rr, 0), c + Vector2(0, rr), c + Vector2(-rr, 0)])
	draw_colored_polygon(pts, fill)
	var outline: PackedVector2Array = pts.duplicate()
	outline.append(pts[0])
	# Lleno: borde oscuro. Hueco: borde del color apagado para que se lea el máximo.
	draw_polyline(outline, CombatStyle.OUTLINE if filled else edge.darkened(0.45), 2.5)


func _text(font: Font, text: String, pos: Vector2, font_size: int, color: Color, outline: int) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, outline, CombatStyle.OUTLINE)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
