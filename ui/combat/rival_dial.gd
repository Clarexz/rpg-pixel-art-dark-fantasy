class_name RivalDial
extends Control
## Zona del rival en combate: un "dial espejo" del dial del jugador. Cuarto de
## disco en la esquina SUPERIOR contraria a la mano, abierto hacia el centro:
## base de piedra, vida del rival en curva, gema de su piedra, su nombre
## siguiendo la curva y, debajo, su estado y la lectura de la piedra.
## Dibujado por código, a pantalla completa, sin recibir toques.
##
## Ángulos propios del dial: 0 = a lo largo de la orilla de arriba (hacia el
## centro), 90 = pegado a la pared. En zurdo todo se espeja en horizontal.

## Margen superior al pivote (DuelUI ya está dentro de la zona segura).
const TOP_MARGIN: float = 8.0
const BASE_R: float = 236.0
const HP_R0: float = 176.0
const HP_R1: float = 204.0
const HP_A0: float = 2.0
const HP_A1: float = 88.0
const GEM_R: float = 88.0
const GEM_SIZE: float = 24.0
const MID_A: float = 45.0
## Arco disponible para el nombre y radios de sus renglones.
const NAME_ARC_DEG: float = 84.0
const NAME_R_ONE: float = 140.0
const NAME_R_TWO: Vector2 = Vector2(132.0, 158.0)
const NAME_SIZE_MAX: int = 24
const NAME_SIZE_MIN: int = 16
const STEP_DEG: float = 3.0
const HP_FLASH_TIME: float = 0.35
## Espacio entre la base y el globo de diálogo (para DuelUI).
const BUBBLE_GAP: float = 72.0

const COLOR_HP: Color = Color8(196, 40, 44)
const COLOR_STONE: Color = Color8(22, 17, 28, 230)
## Color de la gema del rival (más adelante, uno por rival).
const GEM_COLOR: Color = Color8(110, 200, 190)
const COLOR_STATUS: Color = Color(1, 0.85, 0.3)

var left_handed: bool = false:
	set(value):
		left_handed = value
		queue_redraw()
var gem_color: Color = GEM_COLOR:
	set(value):
		gem_color = value
		queue_redraw()
var status_text: String = "":
	set(value):
		status_text = value
		queue_redraw()
## Líneas de lectura de la piedra (cada una empieza con "◆").
var reading_text: String = "":
	set(value):
		reading_text = value
		queue_redraw()

var _name: String = ""
var _lines: PackedStringArray = PackedStringArray()
var _name_size: int = NAME_SIZE_MAX
var _hp: int = 1
var _max_hp: int = 1
var _started: bool = false
var _hp_flash: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(false)


func _ready() -> void:
	resized.connect(_on_resized)


func _on_resized() -> void:
	_fit_name()
	queue_redraw()


# --- Geometría ---------------------------------------------------------------

func _scale() -> float:
	return ArcMenu.scale_for(size.x)


func pivot() -> Vector2:
	return Vector2(size.x if left_handed else 0.0, TOP_MARGIN)


## Radio exterior de la base, en px reales.
func dial_radius() -> float:
	return BASE_R * _scale()


## Y (local) donde puede empezar el globo de diálogo: justo bajo el dial y su texto.
func bubble_top() -> float:
	return pivot().y + (BASE_R + BUBBLE_GAP) * _scale()


func _pt(r: float, deg: float) -> Vector2:
	return ArcMenu.polar(pivot(), r, deg, left_handed)


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


# --- Datos -------------------------------------------------------------------

func set_rival(rival_name: String, hp: int, max_hp: int) -> void:
	if _started and hp < _hp:
		_hp_flash = 1.0
		set_process(true)
	_started = true
	_hp = hp
	_max_hp = maxi(max_hp, 1)
	if rival_name != _name:
		_name = rival_name
		_fit_name()
	queue_redraw()


func hp_value() -> int:
	return _hp


func max_hp_value() -> int:
	return _max_hp


## Renglones del nombre ya ajustados (mayúsculas, quizá recortados con "…").
func name_lines() -> PackedStringArray:
	return _lines


func name_font_size() -> int:
	return _name_size


func _process(delta: float) -> void:
	_hp_flash = maxf(_hp_flash - delta / HP_FLASH_TIME, 0.0)
	queue_redraw()
	if _hp_flash <= 0.0:
		set_process(false)


# --- Ajuste del nombre -------------------------------------------------------

func _text_w(text: String, fs: int) -> float:
	return CombatStyle.title_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


## Largo de arco disponible a un radio (sin escalar) para el escalado actual.
func _arc_len(r: float) -> float:
	return deg_to_rad(NAME_ARC_DEG) * r * _scale()


## Parte las palabras en dos renglones lo más balanceados posible (según el
## ancho relativo a cada arco).
func _best_split(words: PackedStringArray, fs: int) -> PackedStringArray:
	var best: PackedStringArray = PackedStringArray()
	var best_score: float = INF
	for cut: int in range(1, words.size()):
		var l1: String = " ".join(words.slice(0, cut))
		var l2: String = " ".join(words.slice(cut))
		var score: float = maxf(_text_w(l1, fs) / _arc_len(NAME_R_TWO.x), _text_w(l2, fs) / _arc_len(NAME_R_TWO.y))
		if score < best_score:
			best_score = score
			best = PackedStringArray([l1, l2])
	return best


## Recorta con "…" hasta que quepa en `max_w`.
func _trim(text: String, fs: int, max_w: float) -> String:
	if _text_w(text, fs) <= max_w:
		return text
	var t: String = text
	while t.length() > 1 and _text_w(t + "…", fs) > max_w:
		t = t.substr(0, t.length() - 1)
	return t.strip_edges() + "…"


func _fit_name() -> void:
	var text: String = _name.strip_edges().to_upper()
	_lines = PackedStringArray([text])
	_name_size = NAME_SIZE_MAX
	if text.is_empty():
		return
	# (a) Un renglón, bajando el tamaño.
	for fs: int in range(NAME_SIZE_MAX, NAME_SIZE_MIN - 1, -1):
		if _text_w(text, fs) <= _arc_len(NAME_R_ONE):
			_name_size = fs
			return
	var words: PackedStringArray = text.split(" ", false)
	if words.size() >= 2:
		# (b) Dos renglones concéntricos, el mayor tamaño que quepa.
		for fs: int in range(NAME_SIZE_MAX, NAME_SIZE_MIN - 1, -1):
			var two: PackedStringArray = _best_split(words, fs)
			if _text_w(two[0], fs) <= _arc_len(NAME_R_TWO.x) and _text_w(two[1], fs) <= _arc_len(NAME_R_TWO.y):
				_lines = two
				_name_size = fs
				return
		# (c) Aún no cabe: tamaño mínimo y recorte con "…".
		_name_size = NAME_SIZE_MIN
		var cut: PackedStringArray = _best_split(words, _name_size)
		_lines = PackedStringArray([
			_trim(cut[0], _name_size, _arc_len(NAME_R_TWO.x)),
			_trim(cut[1], _name_size, _arc_len(NAME_R_TWO.y))])
		return
	_name_size = NAME_SIZE_MIN
	_lines = PackedStringArray([_trim(text, _name_size, _arc_len(NAME_R_ONE))])


# --- Dibujo ------------------------------------------------------------------

func _draw() -> void:
	var k: float = _scale()
	# Sombra suave y base de piedra (mismo estilo que la del jugador).
	for j: int in 3:
		var grow: float = 18.0 - 6.0 * j
		var sh: PackedVector2Array = _sector(0.0, BASE_R * k + grow, -1.0, 91.0)
		draw_colored_polygon(sh, Color(0, 0, 0, 0.1 + 0.05 * j))
	var stone: PackedVector2Array = _sector(0.0, BASE_R * k, 0.0, 90.0)
	draw_colored_polygon(stone, COLOR_STONE)
	_outline(stone, CombatStyle.OUTLINE, 3.0)
	# Vida: del lado de la orilla de arriba hacia la pared.
	var back: PackedVector2Array = _sector(HP_R0 * k, HP_R1 * k, HP_A0, HP_A1)
	draw_colored_polygon(back, COLOR_HP.darkened(0.72))
	var frac: float = clampf(float(_hp) / float(_max_hp), 0.0, 1.0)
	if frac > 0.0:
		var fill: PackedVector2Array = _sector(HP_R0 * k, HP_R1 * k, HP_A0, HP_A0 + (HP_A1 - HP_A0) * frac)
		draw_colored_polygon(fill, COLOR_HP.lerp(Color.WHITE, _hp_flash))
		_outline(fill, CombatStyle.OUTLINE, 3.0)
	_outline(back, CombatStyle.OUTLINE, 3.0)
	_draw_gem(k)
	_draw_name(k)
	_draw_notes(k)


func _outline(pts: PackedVector2Array, color: Color, w: float) -> void:
	var o: PackedVector2Array = pts.duplicate()
	o.append(pts[0])
	draw_polyline(o, color, w, true)


func _draw_gem(k: float) -> void:
	var c: Vector2 = _pt(GEM_R * k, MID_A)
	var s: float = GEM_SIZE * k
	var body: PackedVector2Array = PackedVector2Array([
		c + Vector2(0, -s), c + Vector2(s * 0.8, 0), c + Vector2(0, s), c + Vector2(-s * 0.8, 0)])
	draw_colored_polygon(body, gem_color)
	_outline(body, CombatStyle.OUTLINE, 3.0)
	var shine: PackedVector2Array = PackedVector2Array([
		c + Vector2(0, -s * 0.6), c + Vector2(s * 0.35, 0), c + Vector2(0, -s * 0.1), c + Vector2(-s * 0.35, 0)])
	draw_colored_polygon(shine, gem_color.lightened(0.7))


func _draw_name(k: float) -> void:
	if _lines.is_empty() or _lines[0].is_empty():
		return
	if _lines.size() == 1:
		_draw_arc_text(_lines[0], NAME_R_ONE * k)
	else:
		_draw_arc_text(_lines[0], NAME_R_TWO.x * k)
		_draw_arc_text(_lines[1], NAME_R_TWO.y * k)


## Cada letra va colocada y girada a lo largo del arco de radio r, centrada en
## el ángulo medio; lee de izquierda a derecha (nunca de cabeza).
func _draw_arc_text(text: String, r: float) -> void:
	var font: Font = CombatStyle.title_font()
	var fs: int = _name_size
	var adv: Array[float] = []
	var total: float = 0.0
	for i: int in text.length():
		var w: float = font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		adv.append(w)
		total += w
	var total_deg: float = rad_to_deg(total / r)
	var walked: float = 0.0
	for i: int in text.length():
		var d: float = rad_to_deg((walked + adv[i] * 0.5) / r)
		walked += adv[i]
		var deg: float = MID_A + total_deg * 0.5 - d if not left_handed else MID_A - total_deg * 0.5 + d
		var rot: float = deg_to_rad(deg - 90.0) if not left_handed else deg_to_rad(90.0 - deg)
		if text[i] == " ":
			continue
		draw_set_transform_matrix(Transform2D(rot, _pt(r, deg)))
		var at: Vector2 = Vector2(-adv[i] * 0.5, fs * 0.35)
		draw_string_outline(font, at, text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, CombatStyle.OUTLINE)
		draw_string(font, at, text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Estado y lectura de la piedra, bajo la base y alineados a su orilla.
func _draw_notes(k: float) -> void:
	var font: Font = get_theme_default_font()
	var w: float = minf(size.x * 0.45, 320.0)
	var x: float = 12.0 if not left_handed else size.x - 12.0 - w
	var align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT if not left_handed else HORIZONTAL_ALIGNMENT_RIGHT
	var y: float = pivot().y + BASE_R * k + 26.0
	if not status_text.is_empty():
		draw_string_outline(font, Vector2(x, y), status_text, align, w, 24, 6, CombatStyle.OUTLINE)
		draw_string(font, Vector2(x, y), status_text, align, w, 24, COLOR_STATUS)
		y += 28.0
	if not reading_text.is_empty():
		draw_multiline_string_outline(font, Vector2(x, y - 2.0), reading_text, align, w, 20, 2, 5, CombatStyle.OUTLINE)
		draw_multiline_string(font, Vector2(x, y - 2.0), reading_text, align, w, 20, 2, gem_color)
