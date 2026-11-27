class_name SpeechBubble
extends Control
## Globo de diálogo del rival: caja de pergamino con contorno oscuro y esquinas
## sesgadas, texto oscuro y una colita hacia abajo (hacia el rival, en el
## centro). Centrado en pantalla; `top_y` es donde empieza la caja. A pantalla
## completa y sin recibir toques. Vacío = oculto.
## También muestra la narración (texto suelto en cursiva, sin globo) en el mismo
## lugar; DuelUI manda solo una de las dos a la vez.

const PAPER: Color = Color8(240, 232, 214)
const INK: Color = Color8(30, 20, 30)
const FONT_SIZE: int = 24
const MAX_W: float = 560.0
const PAD: Vector2 = Vector2(20.0, 14.0)
const SKEW: float = 10.0
const TAIL_H: float = 20.0
const POP_FROM: float = 0.9
const POP_TIME: float = 0.12
const NARR_SIZE: int = 24
const NARR_MAX_W: float = 560.0
const NARR_COLOR: Color = Color8(230, 220, 200)
const NARR_OUTLINE: int = 6
const NARR_SLANT: float = 0.2

var top_y: float = 300.0:
	set(value):
		top_y = value
		queue_redraw()

var _text: String = ""
var _narr: String = ""
var _narr_font: FontVariation
var _pop: float = 1.0:
	set(value):
		_pop = value
		queue_redraw()
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	hide()


func _ready() -> void:
	resized.connect(queue_redraw)


func text() -> String:
	return _text


func narration() -> String:
	return _narr


func say(value: String) -> void:
	var changed: bool = value != _text
	_text = value
	_refresh(changed)


## Narración: sin globo, texto suelto y en cursiva.
func narrate(value: String) -> void:
	var changed: bool = value != _narr
	_narr = value
	_refresh(changed)


func _refresh(changed: bool) -> void:
	visible = not _text.is_empty() or not _narr.is_empty()
	queue_redraw()
	if changed and visible and is_inside_tree():
		if _tween:
			_tween.kill()
		_pop = POP_FROM
		_tween = create_tween()
		_tween.tween_property(self, "_pop", 1.0, POP_TIME).set_ease(Tween.EASE_OUT)


## Tamaño del texto ya con el ancho máximo aplicado.
func _text_size(font: Font) -> Vector2:
	var natural: Vector2 = font.get_multiline_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	if natural.x <= MAX_W - PAD.x * 2.0:
		return natural
	return font.get_multiline_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, MAX_W - PAD.x * 2.0, FONT_SIZE)


## Para las pruebas: rectángulo (local) de la caja, sin la colita.
func box_rect() -> Rect2:
	if _text.is_empty():
		return Rect2()
	var ts: Vector2 = _text_size(get_theme_default_font())
	var box: Vector2 = ts + PAD * 2.0
	return Rect2(Vector2(size.x * 0.5 - box.x * 0.5, top_y), box)


func _italic() -> Font:
	if _narr_font == null:
		_narr_font = FontVariation.new()
		_narr_font.base_font = get_theme_default_font()
		_narr_font.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(NARR_SLANT, 1.0), Vector2.ZERO)
	return _narr_font


## Para las pruebas: rectángulo (local) del texto de la narración.
func narration_rect() -> Rect2:
	if _narr.is_empty():
		return Rect2()
	var font: Font = _italic()
	var ts: Vector2 = font.get_multiline_string_size(_narr, HORIZONTAL_ALIGNMENT_CENTER, NARR_MAX_W, NARR_SIZE)
	var w: float = minf(ts.x, NARR_MAX_W)
	return Rect2(Vector2(size.x * 0.5 - w * 0.5, top_y), Vector2(w, ts.y))


func _draw_narration() -> void:
	var font: Font = _italic()
	var r: Rect2 = narration_rect()
	var c: Vector2 = r.get_center()
	draw_set_transform_matrix(Transform2D(0.0, Vector2(_pop, _pop), 0.0, c * (1.0 - _pop)))
	var at: Vector2 = Vector2(r.position.x, r.position.y + font.get_ascent(NARR_SIZE))
	draw_multiline_string_outline(font, at, _narr, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, NARR_SIZE, -1, NARR_OUTLINE, CombatStyle.OUTLINE)
	draw_multiline_string(font, at, _narr, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, NARR_SIZE, -1, NARR_COLOR)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw() -> void:
	if _text.is_empty():
		if not _narr.is_empty():
			_draw_narration()
		return
	var font: Font = get_theme_default_font()
	var r: Rect2 = box_rect()
	var cx: float = r.get_center().x
	var tip: Vector2 = Vector2(cx, r.end.y + TAIL_H)
	draw_set_transform_matrix(Transform2D(0.0, Vector2(_pop, _pop), 0.0, tip * (1.0 - _pop)))
	var box: PackedVector2Array = PackedVector2Array([
		r.position + Vector2(SKEW, 0), Vector2(r.end.x, r.position.y),
		Vector2(r.end.x - SKEW, r.end.y), Vector2(r.position.x, r.end.y)])
	draw_colored_polygon(box, PAPER)
	var edge: PackedVector2Array = box.duplicate()
	edge.append(box[0])
	draw_polyline(edge, CombatStyle.OUTLINE, 3.0, true)
	# Colita: relleno, dos lados con contorno y un trazo de papel que borra la costura.
	var l: Vector2 = Vector2(cx - 14.0, r.end.y)
	var rr: Vector2 = Vector2(cx + 14.0, r.end.y)
	draw_colored_polygon(PackedVector2Array([l, rr, tip]), PAPER)
	draw_polyline(PackedVector2Array([l, tip, rr]), CombatStyle.OUTLINE, 3.0, true)
	draw_line(l + Vector2(2, 0), rr - Vector2(2, 0), PAPER, 4.0)
	draw_multiline_string(font, r.position + Vector2(PAD.x, PAD.y + font.get_ascent(FONT_SIZE)), _text,
			HORIZONTAL_ALIGNMENT_LEFT, r.size.x - PAD.x * 2.0, FONT_SIZE, -1, INK)
	draw_set_transform_matrix(Transform2D.IDENTITY)
