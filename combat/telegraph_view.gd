class_name TelegraphView
extends Control
## Aviso del ataque del enemigo: una flecha del lado por donde viene y un aro
## que se encoge. Cuando el aro toca el círculo dorado, ¡pega! Si bloqueas
## justo en ese momento (aro dentro de lo dorado) es un bloqueo perfecto.
##
## - Finta: el aro es morado y dice "?" hasta que cambia de lado.
## - Combo: antes de empezar se ven los lados numerados en orden.

const COLOR_STRIKE: Color = Color(1, 0.3, 0.25)
const COLOR_FEINT: Color = Color(0.75, 0.45, 1.0)
const XS: Array[float] = [0.2, 0.5, 0.8]

var _side: int = -1
var _windup: float = 1.0
var _perfect: float = 0.25
var _elapsed: float = 0.0
var _feint: bool = false
var _preview: Array[int] = []
var _preview_left: float = 0.0


func start(side: int, windup: float, perfect_window: float, feint: bool = false) -> void:
	_side = side
	_windup = windup
	_perfect = perfect_window
	_elapsed = 0.0
	_feint = feint
	_preview = []
	queue_redraw()


func retarget(side: int) -> void:
	_side = side
	_feint = false
	queue_redraw()


func preview(sides: Array[int]) -> void:
	_preview = sides.duplicate()
	_preview_left = 0.9
	queue_redraw()


func stop() -> void:
	_side = -1
	_feint = false
	queue_redraw()


func _process(delta: float) -> void:
	if _preview_left > 0.0:
		_preview_left -= delta
		if _preview_left <= 0.0:
			_preview = []
		queue_redraw()
	if _side == -1:
		return
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	# Vista previa del combo: los lados numerados.
	for i: int in _preview.size():
		var p: Vector2 = Vector2(size.x * XS[_preview[i]], size.y * 0.3 + i * 22.0)
		draw_circle(p, 34.0, Color(COLOR_STRIKE, 0.75))
		_label(font, p + Vector2(-11, 16), str(i + 1), 46)
	if _side == -1:
		return
	var color: Color = COLOR_FEINT if _feint else COLOR_STRIKE
	var center: Vector2 = Vector2(size.x * XS[_side], size.y * 0.42)
	var target_r: float = 46.0
	# El aro empieza grande y llega a target_r justo en el impacto.
	var t: float = clampf(_elapsed / _windup, 0.0, 1.0)
	var r: float = lerpf(190.0, target_r, t)
	var in_perfect: bool = _windup - _elapsed <= _perfect
	var gold: Color = Color(1.0, 0.82, 0.25)
	draw_circle(center, target_r, Color(gold, 0.35 if in_perfect else 0.15))
	draw_arc(center, target_r, 0.0, TAU, 48, gold, 4.0, true)
	draw_arc(center, r, 0.0, TAU, 64, Color(color, 0.9), 6.0, true)
	# Flecha apuntando hacia ti (hacia abajo), con "!" (o "?" si es finta).
	var tip: Vector2 = center + Vector2(0, 120)
	var arrow: PackedVector2Array = PackedVector2Array([
		tip, tip + Vector2(-44, -50), tip + Vector2(-16, -50), tip + Vector2(-16, -84),
		tip + Vector2(16, -84), tip + Vector2(16, -50), tip + Vector2(44, -50),
	])
	draw_colored_polygon(arrow, Color(color, 0.85))
	_label(font, center + Vector2(-14, 22), "?" if _feint else "!", 64)


func _label(font: Font, pos: Vector2, text: String, font_size: int) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 10, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
