class_name TelegraphView
extends Control
## Aviso del ataque del rival: una flecha del lado por donde viene y un aro
## que se encoge. Cuando el aro toca el círculo dorado, ¡pega! Si bloqueas
## justo en ese momento (aro dentro de lo dorado) es un bloqueo perfecto.

var _side: int = -1
var _windup: float = 1.0
var _perfect: float = 0.25
var _elapsed: float = 0.0


func start(side: int, windup: float, perfect_window: float) -> void:
	_side = side
	_windup = windup
	_perfect = perfect_window
	_elapsed = 0.0
	queue_redraw()


func stop() -> void:
	_side = -1
	queue_redraw()


func _process(delta: float) -> void:
	if _side == -1:
		return
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	if _side == -1:
		return
	var x: float = size.x * [0.2, 0.5, 0.8][_side]
	var center: Vector2 = Vector2(x, size.y * 0.42)
	var target_r: float = 46.0
	# El aro empieza grande y llega a target_r justo en el impacto.
	var t: float = clampf(_elapsed / _windup, 0.0, 1.0)
	var r: float = lerpf(190.0, target_r, t)
	var in_perfect: bool = _windup - _elapsed <= _perfect
	var gold: Color = Color(1.0, 0.82, 0.25)
	draw_circle(center, target_r, Color(gold, 0.35 if in_perfect else 0.15))
	draw_arc(center, target_r, 0.0, TAU, 48, gold, 4.0, true)
	draw_arc(center, r, 0.0, TAU, 64, Color(1, 0.3, 0.25, 0.9), 6.0, true)
	# Flecha apuntando hacia ti (hacia abajo), con "!" encima.
	var tip: Vector2 = center + Vector2(0, 120)
	var arrow: PackedVector2Array = PackedVector2Array([
		tip, tip + Vector2(-44, -50), tip + Vector2(-16, -50), tip + Vector2(-16, -84),
		tip + Vector2(16, -84), tip + Vector2(16, -50), tip + Vector2(44, -50),
	])
	draw_colored_polygon(arrow, Color(1, 0.3, 0.25, 0.85))
	var font: Font = get_theme_default_font()
	draw_string_outline(font, center + Vector2(-12, 22), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, 10, Color.BLACK)
	draw_string(font, center + Vector2(-12, 22), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color.WHITE)
