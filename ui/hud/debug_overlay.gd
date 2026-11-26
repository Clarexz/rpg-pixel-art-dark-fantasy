extends Label
## Muestra FPS y datos de pantalla. Útil en todas las fases para medir.
##
## Analogía web: un componente React que hace setState cada cierto tiempo.

const REFRESH_SECONDS: float = 0.25

var _elapsed: float = 0.0


# _process corre UNA VEZ POR FRAME (60 veces por segundo si vamos a 60 FPS).
# Analogía web: requestAnimationFrame. "delta" son los segundos desde el
# frame anterior (≈0.016 a 60 FPS).
func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < REFRESH_SECONDS:
		return
	_elapsed = 0.0

	var window: Vector2i = DisplayServer.window_get_size()
	var lines: PackedStringArray = [
		"FPS: %d" % Engine.get_frames_per_second(),
		"Pantalla: %dx%d" % [window.x, window.y],
		"Renderer: %s" % RenderingServer.get_current_rendering_method(),
		"v%s" % ProjectSettings.get_setting("application/config/version"),
	]
	var safe_area: SafeAreaContainer = _find_safe_area()
	if safe_area:
		var i: Dictionary = safe_area.current_insets
		lines.append("Safe area T%d B%d L%d R%d" % [i.top, i.bottom, i.left, i.right])
	text = "\n".join(lines)


func _find_safe_area() -> SafeAreaContainer:
	var node: Node = get_parent()
	while node:
		if node is SafeAreaContainer:
			return node
		node = node.get_parent()
	return null
