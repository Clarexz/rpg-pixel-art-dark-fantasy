class_name SpeechBubble
extends Control
## Globo de diálogo del rival: caja de pergamino con contorno oscuro y esquinas
## sesgadas, texto oscuro y una colita hacia abajo (hacia el rival, en el
## centro). Centrado en pantalla; `top_y` es donde empieza la caja. A pantalla
## completa y sin recibir toques. Vacío = oculto.

const PAPER: Color = Color8(240, 232, 214)
const INK: Color = Color8(30, 20, 30)
const FONT_SIZE: int = 24
const MAX_W: float = 560.0
const PAD: Vector2 = Vector2(20.0, 14.0)
const SKEW: float = 10.0
const TAIL_H: float = 20.0
const POP_FROM: float = 0.9
const POP_TIME: float = 0.12

var top_y: float = 300.0:
	set(value):
		top_y = value
		queue_redraw()

var _text: String = ""
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


func say(value: String) -> void:
	var changed: bool = value != _text
	_text = value
	visible = not value.is_empty()
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


func _draw() -> void:
	if _text.is_empty():
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
