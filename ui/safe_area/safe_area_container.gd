class_name SafeAreaContainer
extends MarginContainer
## Contenedor que mete a sus hijos dentro de la "zona segura" de la pantalla:
## evita el notch, la cámara perforada y la barra de gestos de Android.
##
## Analogía web: es el equivalente a
##   padding: env(safe-area-inset-top) env(safe-area-inset-right) ...
## Toda la UI (HUD, botones) debe ir dentro de uno de estos.

## Margen extra (en px de la UI) además del que pide el sistema.
@export var extra_margin: int = 8
## Solo para probar en PC: simula un notch de este alto (px de pantalla).
@export var simulated_top_inset_on_desktop: int = 0

var current_insets: Dictionary = {"top": 0, "bottom": 0, "left": 0, "right": 0}


func _ready() -> void:
	# Ocupar toda la pantalla, como un div con position:fixed; inset:0.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# "Señal": evento al que nos suscribimos, como addEventListener("resize").
	get_viewport().size_changed.connect(_update_margins)
	_update_margins()


func _update_margins() -> void:
	var window_size: Vector2 = Vector2(DisplayServer.window_get_size())
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return

	var safe: Rect2 = Rect2(Vector2.ZERO, window_size)
	if OS.has_feature("mobile"):
		safe = Rect2(DisplayServer.get_display_safe_area())
	elif simulated_top_inset_on_desktop > 0:
		safe.position.y = simulated_top_inset_on_desktop
		safe.size.y -= simulated_top_inset_on_desktop

	# La safe area viene en píxeles físicos; la UI vive en píxeles "lógicos"
	# (720x1280 escalados). Convertimos, igual que CSS px vs device px.
	var ui_size: Vector2 = get_viewport().get_visible_rect().size
	var to_ui: Vector2 = ui_size / window_size

	current_insets = {
		"top": int(safe.position.y * to_ui.y),
		"left": int(safe.position.x * to_ui.x),
		"bottom": int((window_size.y - safe.end.y) * to_ui.y),
		"right": int((window_size.x - safe.end.x) * to_ui.x),
	}
	add_theme_constant_override("margin_top", current_insets.top + extra_margin)
	add_theme_constant_override("margin_left", current_insets.left + extra_margin)
	add_theme_constant_override("margin_bottom", current_insets.bottom + extra_margin)
	add_theme_constant_override("margin_right", current_insets.right + extra_margin)
