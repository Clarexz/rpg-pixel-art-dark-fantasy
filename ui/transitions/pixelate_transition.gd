class_name PixelateTransition
extends CanvasLayer
## Transición "en el lugar" entre explorar y pelear: la pantalla se pixela,
## y mientras está tapada acomodamos la escena (rival enfrente, UI del duelo).
## No hay pantalla de carga: el mundo sigue ahí.
##
## Uso:  await transition.cover()   ...cambiar cosas...   await transition.reveal()

const MAX_PIXEL: float = 42.0

var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	layer = 5  # encima del HUD (1), debajo de la UI del duelo (10)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://ui/transitions/pixelate.gdshader")
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	add_child(_rect)
	_rect.hide()


func cover(duration: float = 0.3) -> void:
	_rect.show()
	var tween: Tween = create_tween().set_parallel()
	tween.tween_method(_set_param.bind("pixel_size"), 1.0, MAX_PIXEL, duration).set_ease(Tween.EASE_IN)
	tween.tween_method(_set_param.bind("tint_amount"), 0.0, 0.35, duration)
	tween.tween_method(_set_param.bind("darken"), 0.0, 0.3, duration)
	await tween.finished


func reveal(duration: float = 0.3) -> void:
	var tween: Tween = create_tween().set_parallel()
	tween.tween_method(_set_param.bind("pixel_size"), MAX_PIXEL, 1.0, duration).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_param.bind("tint_amount"), 0.35, 0.0, duration)
	tween.tween_method(_set_param.bind("darken"), 0.3, 0.0, duration)
	await tween.finished
	_rect.hide()


func _set_param(value: float, param: String) -> void:
	_mat.set_shader_parameter(param, value)
