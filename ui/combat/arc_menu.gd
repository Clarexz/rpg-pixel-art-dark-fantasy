class_name ArcMenu
extends Control
## Menú en arco alrededor de la base del pulgar. El pulgar gira sobre su base
## (la esquina inferior del lado de la mano), así que los sectores de un anillo
## alrededor de esa esquina quedan igual de cerca de él.
##
## Cada entrada es un sector anular: {text, color, ring, a0, a1, disabled} y,
## opcionalmente, {icon: &"sword"/&"shield"/&"back", arrow: &"izq"/&"centro"/&"der",
## font_max}. Anillos 0 y 1: los de siempre; 2 = botón central (disco r 0-118);
## 3 = franja exterior (r 458-500).
## Ángulos en grados medidos desde el pivote P, para mano derecha: 180 apunta a
## la izquierda y 270 hacia arriba. En zurdo todo se espeja en horizontal.
## Reacciona al TOCAR (no al soltar), igual que los botones de DuelUI.

signal pressed(index: int)

## Radios de cada anillo (0 = interior, el más usado; 1 = exterior).
const RING_IN: Array[float] = [220.0, 370.0, 0.0, 458.0]
const RING_OUT: Array[float] = [340.0, 450.0, 118.0, 500.0]
## Radio (sin escalar) del ícono y de la flecha en cada anillo.
const ICON_R: Array[float] = [262.0, 395.0, 70.0, 479.0]
const ARROW_R: Array[float] = [305.0, 428.0, 70.0, 479.0]
const RING_COUNT: int = 4
## Cuánto aguantan los toques fuera del sector (px): los huecos van al vecino.
const HIT_TOLERANCE: float = 16.0
const OUTLINE_W: float = 4.0
const STEP_DEG: float = 3.0
const SHOW_TIME: float = 0.18
const RING_DELAY: float = 0.05
const PRESS_TIME: float = 0.15
const MARK_TIME: float = 0.25
const START_SCALE: float = 0.85
const FONT_MAX: int = 34
const FONT_MIN: int = 18

var left_handed: bool = false:
	set(value):
		left_handed = value
		queue_redraw()
## Separación entre el pivote y el borde inferior (la zona segura de abajo).
var bottom_margin: float = 24.0:
	set(value):
		bottom_margin = value
		queue_redraw()

var _entries: Array[Dictionary] = []
var _pressed: int = -1
var _down_ms: int = -1000
var _show_t: Array[float] = [1.0, 1.0, 1.0, 1.0]
var _tween: Tween
var _marked: int = -1
var _mark_color: Color = Color.WHITE


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	resized.connect(queue_redraw)


## entries: [{text, color, ring, a0, a1, disabled}]. animate = se despliegan
## desde el pivote (escala 0.85 a 1 y aparecen, el anillo interior primero).
func set_entries(entries: Array[Dictionary], animate: bool = true) -> void:
	_entries = entries
	_pressed = -1
	_marked = -1
	if _tween:
		_tween.kill()
	if animate:
		_show_t = [0.0, 0.0, 0.0, 0.0]
		_tween = create_tween().set_parallel()
		for ring: int in RING_COUNT:
			_tween.tween_method(_set_show.bind(ring), 0.0, 1.0, SHOW_TIME) \
					.set_delay(RING_DELAY * (ring % 2)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	else:
		_show_t = [1.0, 1.0, 1.0, 1.0]
	queue_redraw()


## Enciende o apaga una entrada sin volver a desplegar el menú.
func set_entry_disabled(index: int, disabled: bool) -> void:
	if index < 0 or index >= _entries.size():
		return
	_entries[index].disabled = disabled
	queue_redraw()


## Resalta una entrada un instante (aclarada, con el tinte de `color`).
func mark_entry(index: int, color: Color = Color.WHITE) -> void:
	if index < 0 or index >= _entries.size():
		return
	_marked = index
	_mark_color = color
	queue_redraw()
	get_tree().create_timer(MARK_TIME).timeout.connect(_release_mark.bind(index))


func _release_mark(index: int) -> void:
	if _marked == index:
		_marked = -1
		queue_redraw()


func entry_count() -> int:
	return _entries.size()


## Pivote P en coordenadas locales: esquina inferior del lado de la mano.
func pivot() -> Vector2:
	return Vector2(0.0 if left_handed else size.x, size.y - bottom_margin)


## Punto (global) del centro del sector: radio y ángulo medios. Para las pruebas
## y para saber dónde cae cada entrada.
func point_for(index: int) -> Vector2:
	var e: Dictionary = _entries[index]
	return get_global_transform() * _polar(pivot(), _mid_radius(e), (float(e.a0) + float(e.a1)) * 0.5)


## Índice de la entrada bajo un punto local, o -1. Los huecos entre sectores
## se resuelven al vecino más cercano (con HIT_TOLERANCE de margen).
func index_at(local: Vector2) -> int:
	var k: float = _scale()
	var v: Vector2 = local - pivot()
	if left_handed:
		v.x = -v.x
	var r: float = v.length()
	var theta: float = fposmod(rad_to_deg(atan2(v.y, v.x)), 360.0)
	var best: int = -1
	var best_d: float = HIT_TOLERANCE
	for i: int in _entries.size():
		var e: Dictionary = _entries[i]
		var ring: int = int(e.ring)
		var dr: float = maxf(0.0, maxf(RING_IN[ring] * k - r, r - RING_OUT[ring] * k))
		var da: float = maxf(0.0, maxf(float(e.a0) - theta, theta - float(e.a1)))
		var d: float = Vector2(dr, deg_to_rad(da) * r).length()
		if d < best_d:
			best_d = d
			best = i
	return best


func _has_point(point: Vector2) -> bool:
	return visible and index_at(point) >= 0


func _gui_input(event: InputEvent) -> void:
	var pos: Vector2
	var down: bool
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pos = (event as InputEventMouseButton).position
		down = (event as InputEventMouseButton).pressed
	elif event is InputEventScreenTouch:
		pos = (event as InputEventScreenTouch).position
		down = (event as InputEventScreenTouch).pressed
	else:
		return
	accept_event()
	if not down:
		_down_ms = -1000
		return
	# El toque llega como ScreenTouch y como clic emulado: contar uno solo.
	var now: int = Time.get_ticks_msec()
	if now - _down_ms < 250:
		return
	_down_ms = now
	var i: int = index_at(pos)
	if i < 0 or bool(_entries[i].get("disabled", false)):
		return
	_pressed = i
	queue_redraw()
	get_tree().create_timer(PRESS_TIME).timeout.connect(_release_press.bind(i))
	pressed.emit(i)


func _release_press(i: int) -> void:
	if _pressed == i:
		_pressed = -1
		queue_redraw()


func _set_show(value: float, ring: int) -> void:
	_show_t[ring] = value
	queue_redraw()


# --- Geometría -------------------------------------------------------------------

## Escala los radios si la pantalla es más angosta que 720.
func _scale() -> float:
	return ArcMenu.scale_for(size.x)


func _mid_radius(e: Dictionary) -> float:
	var ring: int = int(e.ring)
	return (RING_IN[ring] + RING_OUT[ring]) * 0.5 * _scale()


func _polar(p: Vector2, r: float, deg: float) -> Vector2:
	return ArcMenu.polar(p, r, deg, left_handed)


## Punto a distancia r y ángulo deg (grados, 180 = izquierda, 270 = arriba)
## de p; en zurdo se espeja en horizontal. Lo comparte el HUD del jugador.
static func polar(p: Vector2, r: float, deg: float, mirrored: bool) -> Vector2:
	var a: float = deg_to_rad(deg)
	var dx: float = cos(a) * r
	return p + Vector2(-dx if mirrored else dx, sin(a) * r)


## Escala de los radios para un ancho de pantalla dado.
static func scale_for(width: float) -> float:
	return clampf(width / 720.0, 0.6, 1.0)


## Polígono del sector, encogido `inset` px por todos los lados.
func _sector_points(e: Dictionary, inset: float) -> PackedVector2Array:
	var k: float = _scale()
	var ring: int = int(e.ring)
	var r0: float = maxf(RING_IN[ring] * k, 1.0) + inset
	var r1: float = RING_OUT[ring] * k - inset
	# El recorte en ángulo es constante en px: se convierte con cada radio.
	var a0: float = float(e.a0)
	var a1: float = float(e.a1)
	var p: Vector2 = pivot()
	var pts: PackedVector2Array = PackedVector2Array()
	var da_out: float = rad_to_deg(inset / r1)
	var da_in: float = rad_to_deg(inset / r0)
	var steps: int = maxi(2, ceili((a1 - a0) / STEP_DEG))
	for s: int in steps + 1:
		var t: float = float(s) / steps
		pts.append(_polar(p, r1, lerpf(a0 + da_out, a1 - da_out, t)))
	if RING_IN[ring] <= 0.0:
		# Disco: el borde interior es el propio pivote.
		pts.append(p)
		return pts
	for s: int in steps + 1:
		var t: float = 1.0 - float(s) / steps
		pts.append(_polar(p, r0, lerpf(a0 + da_in, a1 - da_in, t)))
	return pts


# --- Dibujo ----------------------------------------------------------------------

func _draw() -> void:
	var p: Vector2 = pivot()
	for i: int in _entries.size():
		var e: Dictionary = _entries[i]
		var ring: int = int(e.ring)
		var t: float = _show_t[ring]
		if t <= 0.0:
			continue
		var sc: float = lerpf(START_SCALE, 1.0, t)
		# Escala alrededor de P: los sectores se despliegan desde la esquina.
		var base: Transform2D = Transform2D(0.0, Vector2(sc, sc), 0.0, p * (1.0 - sc))
		draw_set_transform_matrix(base)
		var color: Color = e.color
		var disabled: bool = bool(e.get("disabled", false))
		if disabled:
			color = color.darkened(0.65)
			color.s *= 0.4
		elif i == _pressed:
			color = color.lightened(0.35)
		elif i == _marked:
			color = color.lerp(_mark_color, 0.35).lightened(0.35)
		var fade: Color = Color(1, 1, 1, t)
		var pts: PackedVector2Array = _sector_points(e, OUTLINE_W * 0.5)
		# Sombra suave hacia abajo y afuera.
		var shadow: PackedVector2Array = PackedVector2Array()
		for q: Vector2 in pts:
			shadow.append(q + Vector2(-4 if left_handed else 4, 4))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.5 * t))
		draw_colored_polygon(pts, color * fade)
		# Brillo sutil: línea clara dentro del borde.
		var glow: PackedVector2Array = _sector_points(e, OUTLINE_W + 3.0)
		glow.append(glow[0])
		draw_polyline(glow, Color(1, 1, 1, 0.22 * t), 2.0, true)
		pts.append(pts[0])
		draw_polyline(pts, CombatStyle.OUTLINE * fade, OUTLINE_W, true)
		_draw_label(e, t, disabled, base)
		_draw_icons(e, t, disabled, base)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Texto girado a lo largo del arco (tangente), nunca de cabeza.
func _draw_label(e: Dictionary, alpha: float, disabled: bool, base: Transform2D) -> void:
	var font: Font = CombatStyle.title_font()
	var mid_deg: float = (float(e.a0) + float(e.a1)) * 0.5
	var center: Vector2 = _polar(pivot(), _mid_radius(e), mid_deg)
	var radial: Vector2 = (center - pivot()).normalized()
	var tangent: Vector2 = Vector2(-radial.y, radial.x)
	if tangent.x < 0.0:
		tangent = -tangent
	var text: String = String(e.get("text", ""))
	if text.is_empty():
		return
	var lines: PackedStringArray = text.split("\n")
	var ring: int = int(e.ring)
	var k: float = _scale()
	var r: float = _mid_radius(e)
	# Espacio disponible: cuerda del arco (a lo largo) y grosor del anillo.
	var arc_room: float = deg_to_rad(float(e.a1) - float(e.a0)) * r * 0.82
	var thick_room: float = (RING_OUT[ring] - RING_IN[ring]) * k * 0.8
	var font_max: int = int(e.get("font_max", FONT_MAX))
	var font_min: int = mini(FONT_MIN, font_max)
	var main_size: int = font_max
	var sizes: Array[int] = []
	var total_h: float = 0.0
	while true:
		sizes.clear()
		total_h = 0.0
		var widest: float = 0.0
		for line: String in lines:
			var fs: int = main_size
			if _is_hint(line):
				fs = maxi(FONT_MIN - 4, roundi(main_size * 0.62))
			sizes.append(fs)
			total_h += fs * 1.15
			widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		if main_size <= font_min or (widest <= arc_room and total_h <= thick_room):
			break
		main_size -= 2
	var col: Color = Color(1, 1, 1, (0.3 if disabled else 1.0) * alpha)
	var outline: Color = CombatStyle.OUTLINE
	outline.a = alpha
	# La base del texto se gira con el ángulo de la tangente.
	var ang: float = tangent.angle()
	draw_set_transform_matrix(base * Transform2D(ang, center))
	var y: float = -total_h * 0.5
	for li: int in lines.size():
		var fs: int = sizes[li]
		var w: float = font.get_string_size(lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var baseline: float = y + fs * 0.95
		var at: Vector2 = Vector2(-w * 0.5, baseline)
		draw_string_outline(font, at, lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, outline)
		draw_string(font, at, lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		y += fs * 1.15
	draw_set_transform_matrix(base)


func _is_hint(line: String) -> bool:
	return line.begins_with("(")


# --- Íconos (dibujados por código) -------------------------------------------------

func _draw_icons(e: Dictionary, alpha: float, disabled: bool, base: Transform2D) -> void:
	var icon: StringName = e.get("icon", &"")
	var arrow: StringName = e.get("arrow", &"")
	if icon == &"" and arrow == &"":
		return
	draw_set_transform_matrix(base)
	var ring: int = int(e.ring)
	var k: float = _scale()
	var mid_deg: float = (float(e.a0) + float(e.a1)) * 0.5
	var col: Color = Color(0.92, 0.92, 0.95, (0.3 if disabled else 1.0) * alpha)
	var line: Color = Color(1, 1, 1, (0.3 if disabled else 1.0) * alpha)
	var out: Color = CombatStyle.OUTLINE
	out.a = alpha
	var ic: Vector2 = _polar(pivot(), ICON_R[ring] * k, mid_deg)
	match icon:
		&"sword":
			_draw_sword(ic, col, out, k)
		&"shield":
			_draw_shield(ic, col, out, k)
		&"back":
			_draw_back(ic, line, out, k)
	if arrow != &"":
		_draw_arrow(_polar(pivot(), ARROW_R[ring] * k, mid_deg), arrow, line, out, 13.0 * k)
	draw_set_transform_matrix(base)


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var o: PackedVector2Array = pts.duplicate()
	o.append(pts[0])
	return o


func _draw_sword(c: Vector2, col: Color, out: Color, k: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for q: Vector2 in [Vector2(-14, 14), Vector2(10, -10), Vector2(16, -16), Vector2(14, -8), Vector2(-10, 16)]:
		pts.append(c + q * k)
	draw_colored_polygon(pts, col)
	draw_polyline(_closed(pts), out, 3.0, true)
	draw_line(c + Vector2(-13, 3) * k, c + Vector2(-3, 13) * k, out, 6.0)
	draw_line(c + Vector2(-12, 4) * k, c + Vector2(-4, 12) * k, col, 3.0)


func _draw_shield(c: Vector2, col: Color, out: Color, k: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for q: Vector2 in [Vector2(-14, -14), Vector2(14, -14), Vector2(14, 2), Vector2(0, 16), Vector2(-14, 2)]:
		pts.append(c + q * k)
	draw_colored_polygon(pts, col)
	draw_polyline(_closed(pts), out, 3.0, true)


func _draw_arrow(c: Vector2, dir: StringName, col: Color, out: Color, s: float) -> void:
	var ang: float = {&"izq": PI, &"centro": -PI * 0.5, &"der": 0.0}.get(dir, 0.0)
	var v: Vector2 = Vector2.from_angle(ang)
	var tip: Vector2 = c + v * s
	var tail: Vector2 = c - v * s
	var heads: Array[Vector2] = []
	for da: float in [deg_to_rad(150.0), deg_to_rad(-150.0)]:
		heads.append(tip + Vector2.from_angle(ang + da) * s * 0.8)
	for pass_i: int in 2:
		var w: float = 9.0 if pass_i == 0 else 5.0
		var cc: Color = out if pass_i == 0 else col
		draw_line(tail, tip, cc, w)
		for h: Vector2 in heads:
			draw_line(tip, h, cc, w)


## Flecha curva "volver" (↩): arco de ~250° con la punta en el extremo.
func _draw_back(c: Vector2, col: Color, out: Color, k: float) -> void:
	var r: float = 22.0 * k
	var a0: float = deg_to_rad(-150.0)
	var a1: float = deg_to_rad(100.0)
	var arc: PackedVector2Array = PackedVector2Array()
	for s: int in 16:
		arc.append(c + Vector2.from_angle(lerpf(a0, a1, float(s) / 15.0)) * r)
	var tang: Vector2 = Vector2.from_angle(a1 + PI * 0.5)
	var tip: Vector2 = arc[arc.size() - 1] + tang * 4.0 * k
	var heads: Array[Vector2] = []
	for da: float in [deg_to_rad(150.0), deg_to_rad(-150.0)]:
		heads.append(tip + tang.rotated(da) * 15.0 * k)
	for pass_i: int in 2:
		var w: float = 10.0 if pass_i == 0 else 6.0
		var cc: Color = out if pass_i == 0 else col
		draw_polyline(arc, cc, w, true)
		for h: Vector2 in heads:
			draw_line(tip, h, cc, w)
