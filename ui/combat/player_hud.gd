class_name PlayerHud
extends Control
## Estado del jugador en combate, integrado en el arco del menú: PV como un
## arco largo, y PA / PM como segmentos curvos, uno por punto máximo (encendido =
## disponible, apagado = gastado). Dibujado por código, a pantalla completa y
## por debajo del ArcMenu (que comparte pivote y geometría).
##
## Dos modos (propiedad `compact`):
## - Completo: pivote = el del arco (esquina de la mano). Base de piedra grande
##   detrás del arco; PV y PA/PM caen justo en los bordes de los anillos.
## - Compacto: cuando la cuadrícula/hechizos/items ocupan la esquina de la
##   mano, el HUD pasa a un cuarto de disco de 214 px en la esquina contraria,
##   abierto hacia el centro. No llega a la cuadrícula (empieza en x≈224).
## Ángulos como en ArcMenu (diestro: 180 = izquierda, 270 = arriba; zurdo espeja).

const BOTTOM_MARGIN: float = 24.0
## Radio del cuarto de disco del modo compacto.
const COMPACT_R: float = 214.0
const STEP_DEG: float = 3.0
const SEG_GAP_DEG: float = 1.6

const COLOR_HP: Color = Color8(196, 40, 44)
const COLOR_PA: Color = CombatStyle.MELEE
const COLOR_PM: Color = Color8(140, 120, 255)
const COLOR_OFF: Color = Color8(40, 34, 46)
const COLOR_STONE: Color = Color8(22, 17, 28, 230)

const HP_FLASH_TIME: float = 0.35
const PIP_ANIM_TIME: float = 0.3
const MODE_FADE_TIME: float = 0.15

## Rangos de ángulo (iguales en los dos modos): PA junto al suelo, PM hacia arriba.
const PA_A: Vector2 = Vector2(182.0, 223.0)
const PM_A: Vector2 = Vector2(227.0, 268.0)
const HP_A: Vector2 = Vector2(182.0, 268.0)

var left_handed: bool = false:
	set(value):
		left_handed = value
		queue_redraw()
var compact: bool = false:
	set(value):
		if value == compact:
			return
		compact = value
		_fade_in()
		queue_redraw()

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
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(false)


func _ready() -> void:
	resized.connect(queue_redraw)


# --- Geometría compartida ----------------------------------------------------

func _scale() -> float:
	return ArcMenu.scale_for(size.x)


## El modo compacto va en la esquina contraria, y todo se espeja con ella.
func _mirrored() -> bool:
	return left_handed != compact


## Pivote local del modo actual. En modo completo coincide con ArcMenu.pivot().
func pivot() -> Vector2:
	return Vector2(0.0 if _mirrored() else size.x, size.y - BOTTOM_MARGIN)


## Radio exterior de la base (para las pruebas): lo que ocupa el HUD desde su pivote.
func dial_radius() -> float:
	return (COMPACT_R if compact else 462.0) * _scale()


## Geometría del modo actual (radios sin escalar).
func _geo() -> Dictionary:
	if compact:
		return {"base": Vector2(0.0, COMPACT_R), "base_a": Vector2(180.0, 270.0),
				"hp": Vector2(150.0, 170.0), "seg": Vector2(112.0, 132.0),
				"num_r": 62.0, "num_a": 225.0, "num_size": 32}
	return {"base": Vector2(170.0, 462.0), "base_a": Vector2(179.0, 271.0),
			"hp": Vector2(184.0, 208.0), "seg": Vector2(344.0, 366.0),
			"num_r": 154.0, "num_a": 186.0, "num_size": 30}


func _pt(r: float, deg: float) -> Vector2:
	return ArcMenu.polar(pivot(), r, deg, _mirrored())


## Sector anular (o de disco si r0 <= 0), r en px reales.
func _sector(r0: float, r1: float, a0: float, a1: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var steps: int = maxi(2, ceili(absf(a1 - a0) / STEP_DEG))
	for s: int in steps + 1:
		pts.append(_pt(r1, lerpf(a0, a1, float(s) / steps)))
	if r0 <= 0.5:
		pts.append(pivot())
	else:
		for s: int in steps + 1:
			pts.append(_pt(r0, lerpf(a1, a0, float(s) / steps)))
	return pts


func _seg_range(kind: StringName) -> Vector2:
	return PA_A if kind == &"pa" else PM_A


## Ángulos (a0, a1) del segmento i de `kind`, ya con el hueco entre segmentos.
func _seg_angles(kind: StringName, i: int) -> Vector2:
	var rng: Vector2 = _seg_range(kind)
	var n: int = maxi(pip_count(kind), 1)
	var step: float = (rng.y - rng.x) / n
	return Vector2(rng.x + i * step + SEG_GAP_DEG * 0.5, rng.x + (i + 1) * step - SEG_GAP_DEG * 0.5)


## Para las pruebas: rectángulo global que envuelve al segmento i de `kind`.
func segment_rect_global(kind: StringName, i: int) -> Rect2:
	var g: Dictionary = _geo()
	var k: float = _scale()
	var seg: Vector2 = g.seg
	var a: Vector2 = _seg_angles(kind, i)
	var pts: PackedVector2Array = _sector(seg.x * k, seg.y * k, a.x, a.y)
	var xf: Transform2D = get_global_transform()
	var r: Rect2 = Rect2(xf * pts[0], Vector2.ZERO)
	for q: Vector2 in pts:
		r = r.expand(xf * q)
	return r


# --- Datos -------------------------------------------------------------------

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


## Para las pruebas: cuántos segmentos hay de "pa" o "pm" y cuántos están encendidos.
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


## Marca qué segmentos cambiaron para que hagan "pop" o se enciendan.
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


func _fade_in() -> void:
	if _tween:
		_tween.kill()
	if not is_inside_tree():
		return
	self_modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "self_modulate:a", 1.0, MODE_FADE_TIME)


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


# --- Dibujo ------------------------------------------------------------------

func _draw() -> void:
	var g: Dictionary = _geo()
	var k: float = _scale()
	var base: Vector2 = g.base
	var base_a: Vector2 = g.base_a
	# Sombra suave (polígonos un poco más grandes, cada vez más tenues) y base de piedra.
	for j: int in 3:
		var grow: float = 18.0 - 6.0 * j
		var sh: PackedVector2Array = _sector(maxf(base.x * k - grow, 0.0), base.y * k + grow, base_a.x - 1.0, base_a.y + 1.0)
		draw_colored_polygon(sh, Color(0, 0, 0, 0.1 + 0.05 * j))
	var stone: PackedVector2Array = _sector(base.x * k, base.y * k, base_a.x, base_a.y)
	draw_colored_polygon(stone, COLOR_STONE)
	_outline(stone, CombatStyle.OUTLINE, 3.0)
	# PV: fondo oscuro y relleno proporcional.
	var hp: Vector2 = g.hp
	var back: PackedVector2Array = _sector(hp.x * k, hp.y * k, HP_A.x, HP_A.y)
	draw_colored_polygon(back, COLOR_HP.darkened(0.72))
	var frac: float = clampf(float(_hp) / float(_max_hp), 0.0, 1.0)
	if frac > 0.0:
		var fill: PackedVector2Array = _sector(hp.x * k, hp.y * k, HP_A.x, HP_A.x + (HP_A.y - HP_A.x) * frac)
		draw_colored_polygon(fill, COLOR_HP.lerp(Color.WHITE, _hp_flash))
		_outline(fill, CombatStyle.OUTLINE, 3.0)
	_outline(back, CombatStyle.OUTLINE, 3.0)
	_draw_number(g, k)
	_segments(&"pa", COLOR_PA, g, k)
	_segments(&"pm", COLOR_PM, g, k)


func _outline(pts: PackedVector2Array, color: Color, w: float) -> void:
	var o: PackedVector2Array = pts.duplicate()
	o.append(pts[0])
	draw_polyline(o, color, w, true)


## Rectángulo (local) del número de PV, recto (sin girar). Completo: junto al
## extremo de abajo de la barra, por dentro de la curva y con la base sobre el
## margen inferior. Compacto: centrado en el cuarto de disco.
func number_rect() -> Rect2:
	var g: Dictionary = _geo()
	var k: float = _scale()
	var fs: int = g.num_size
	var font: Font = CombatStyle.title_font()
	var w: float = font.get_string_size(str(_hp), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var h: float = font.get_height(fs)
	if compact:
		var c: Vector2 = _pt(float(g.num_r) * k, g.num_a)
		return Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	# Por dentro de la barra (radio interior de PV), a 10 px de ella.
	var hp: Vector2 = g.hp
	var reach: float = hp.x * k - 10.0
	var x: float = pivot().x + reach - w if _mirrored() else pivot().x - reach
	var y: float = pivot().y - 2.0 - font.get_ascent(fs)
	return Rect2(Vector2(x, y), Vector2(w, h))


## Número de PV, horizontal (nunca girado).
func _draw_number(g: Dictionary, _k: float) -> void:
	var font: Font = CombatStyle.title_font()
	var fs: int = g.num_size
	var r: Rect2 = number_rect()
	var at: Vector2 = Vector2(r.position.x, r.position.y + font.get_ascent(fs))
	var text: String = str(_hp)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, CombatStyle.OUTLINE)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _segments(kind: StringName, color: Color, g: Dictionary, k: float) -> void:
	var seg: Vector2 = g.seg
	var t: Array = _pip_t[kind]
	var dir: Array = _pip_dir[kind]
	var lit: int = lit_count(kind)
	for i: int in pip_count(kind):
		var a: Vector2 = _seg_angles(kind, i)
		var anim: float = t[i] if i < t.size() else 0.0
		var d: float = dir[i] if i < dir.size() else 0.0
		var on: bool = i < lit or (anim > 0.0 and d < 0.0)
		var grow: float = 0.0
		var fill: Color = color if on else COLOR_OFF
		if anim > 0.0:
			# Gastado: crece y se vuelve blanco al apagarse. Recuperado: se enciende con destello.
			grow = (5.0 if d < 0.0 else 3.5) * anim
			if on:
				fill = color.lerp(Color.WHITE, anim)
		var r0: float = seg.x * k - grow
		var r1: float = seg.y * k + grow
		var pts: PackedVector2Array = _sector(r0, r1, a.x, a.y)
		draw_colored_polygon(pts, fill)
		_outline(pts, CombatStyle.OUTLINE, 2.0)
		if on:
			var hl: PackedVector2Array = PackedVector2Array()
			for s: int in 7:
				hl.append(_pt(r1 - 3.0, lerpf(a.x + 0.4, a.y - 0.4, float(s) / 6.0)))
			draw_polyline(hl, color.lightened(0.45), 3.0, true)
