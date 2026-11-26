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
@export var radius: float = 70.0:
	set(value):
		radius = value
		custom_minimum_size = Vector2.ONE * radius * 2.0
		queue_redraw()
@export var color: Color = Color(0.85, 0.3, 0.3)
## Si es true, arrastrar el dedo sobre este botón también gira la cámara
## (como el botón de disparo de los shooters móviles).
@export var drag_looks: bool = false

var pressed: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2.ONE * radius * 2.0


func set_pressed(value: bool) -> void:
	pressed = value
	queue_redraw()


## Zona tocable un poco más grande que el dibujo: los pulgares fallan.
func hit_test(global_point: Vector2) -> bool:
	var center: Vector2 = global_position + size * 0.5
	return global_point.distance_to(center) <= radius * 1.2


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var fill: Color = color
	fill.a = 0.75 if pressed else 0.35
	draw_circle(center, radius * (0.92 if pressed else 1.0), fill)
	draw_arc(center, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.6), 3.0, true)
	var font: Font = get_theme_default_font()
	var font_size: int = int(radius * 0.45)
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var baseline: Vector2 = center + Vector2(-text_size.x * 0.5, font_size * 0.35)
	draw_string_outline(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color.BLACK)
	draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
