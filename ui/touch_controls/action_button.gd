@tool
class_name ActionButton
extends Control
## Botón redondo táctil. No usa el sistema de botones de Godot (que solo
## reacciona al primer dedo); TouchControls decide qué dedo lo toca y nos
## avisa con set_pressed(). Esto permite tocar varios botones a la vez
## mientras el otro pulgar usa el joystick.
##
## @tool hace que el script también corra en el editor, para ver el botón
## dibujado mientras lo acomodas (como un preview en Storybook).

@export var action: StringName = &"attack"
@export var label: String = "ATK":
	set(value):
		label = value
		queue_redraw()
## Forma del botón: círculo (el de siempre), cuadrado o media luna
## (mitad de arriba de un círculo, lado plano abajo).
enum Shape { CIRCLE, SQUARE, HALF_MOON }

@export var shape: Shape = Shape.CIRCLE:
	set(value):
		shape = value
		_update_min_size()
		queue_redraw()
## Tamaño de la caja para CUADRADO y MEDIA LUNA (el círculo usa "radius").
@export var box_size: Vector2 = Vector2(100.0, 100.0):
	set(value):
		box_size = value
		_update_min_size()
		queue_redraw()
@export var radius: float = 70.0:
	set(value):
		radius = value
		_update_min_size()
		queue_redraw()
@export var color: Color = Color(0.85, 0.3, 0.3)
## Si es true, arrastrar el dedo sobre este botón también gira la cámara
## (como el botón de disparo de los shooters móviles).
@export var drag_looks: bool = false

## Escala aplicada al tamaño base (la pone OneHandControls según los ajustes).
## Afecta caja, radio, zona tocable y texto.
var visual_scale: float = 1.0:
	set(value):
		visual_scale = value
		_update_min_size()
		queue_redraw()

var pressed: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_min_size()


func set_pressed(value: bool) -> void:
	pressed = value
	queue_redraw()


## Tamaño de la caja que ocupa el botón, según su forma.
func get_box_size() -> Vector2:
	if shape == Shape.CIRCLE:
		return Vector2.ONE * radius * 2.0 * visual_scale
	return box_size * visual_scale


## Centro del botón en coordenadas globales (para desempatar toques).
func hit_center() -> Vector2:
	return global_position + get_box_size() * 0.5


func _update_min_size() -> void:
	custom_minimum_size = get_box_size()


## Zona tocable un poco más grande que el dibujo: los pulgares fallan.
func hit_test(global_point: Vector2) -> bool:
	if shape == Shape.CIRCLE:
		return global_point.distance_to(hit_center()) <= radius * visual_scale * 1.2
	# Cuadrado y media luna: su caja crecida un 20 %.
	var box: Vector2 = get_box_size()
	return Rect2(hit_center() - box * 0.6, box * 1.2).has_point(global_point)


## Contorno de la forma, ya encogido si está apretado.
func _shape_points(scale_factor: float) -> PackedVector2Array:
	var box: Vector2 = get_box_size()
	var points: PackedVector2Array = PackedVector2Array()
	match shape:
		Shape.CIRCLE:
			var center: Vector2 = box * 0.5
			for i: int in 48:
				var a: float = TAU * i / 48.0
				points.append(center + Vector2(cos(a), sin(a)) * radius * visual_scale * scale_factor)
		Shape.SQUARE:
			var center: Vector2 = box * 0.5
			var half: Vector2 = box * 0.5 * scale_factor
			points.append(center + Vector2(-half.x, -half.y))
			points.append(center + Vector2(half.x, -half.y))
			points.append(center + Vector2(half.x, half.y))
			points.append(center + Vector2(-half.x, half.y))
		Shape.HALF_MOON:
			# Pivote en el centro del lado plano, para que al apretar no se despegue.
			var pivot: Vector2 = Vector2(box.x * 0.5, box.y)
			for i: int in 33:
				var a: float = PI + PI * i / 32.0
				points.append(pivot + Vector2(cos(a) * box.x * 0.5, sin(a) * box.y) * scale_factor)
	return points


func _draw() -> void:
	var fill: Color = color
	fill.a = 1.0 if pressed else 0.85
	var points: PackedVector2Array = _shape_points(0.92 if pressed else 1.0)
	draw_colored_polygon(points, fill)
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, fill.darkened(0.55), 4.0, true)  # borde oscuro del mismo tono (estilo pixel art)
	var box: Vector2 = get_box_size()
	var font: Font = get_theme_default_font()
	var font_size: int = int(radius * visual_scale * 0.45)
	var text_center: Vector2 = box * 0.5
	match shape:
		Shape.SQUARE:
			font_size = int(box.y * 0.23)
		Shape.HALF_MOON:
			font_size = int(box.y * 0.31)
			text_center = Vector2(box.x * 0.5, box.y - font_size * 0.65)
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var baseline: Vector2 = text_center + Vector2(-text_size.x * 0.5, font_size * 0.35)
	draw_string_outline(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color.BLACK)
	draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
