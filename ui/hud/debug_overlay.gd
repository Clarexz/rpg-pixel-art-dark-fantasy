extends Label
## Monitor de rendimiento: FPS, milisegundos por frame, GPU, draw calls y la
## resolución a la que se dibuja el mundo 3D. Se activa/desactiva en Ajustes
## ("Monitor de rendimiento completo"); apagado solo muestra los FPS.
##
## Analogía web: la pestaña Performance de Chrome DevTools, pero pegada en
## la esquina del juego.

const REFRESH_SECONDS: float = 0.5

var _elapsed: float = 0.0
var _frames: int = 0
var _worst_ms: float = 0.0


# _process corre UNA VEZ POR FRAME (60 veces por segundo si vamos a 60 FPS).
# Analogía web: requestAnimationFrame. "delta" son los segundos desde el
# frame anterior (≈0.016 a 60 FPS).
func _process(delta: float) -> void:
	_elapsed += delta
	_frames += 1
	_worst_ms = maxf(_worst_ms, delta * 1000.0)
	if _elapsed < REFRESH_SECONDS:
		return
	var avg_ms: float = _elapsed * 1000.0 / _frames
	var lines: PackedStringArray = []
	if not Graphics.settings.show_perf:
		lines.append("FPS %d" % roundi(1000.0 / avg_ms))
	else:
		lines.append("FPS %d · %.1f ms (peor %.0f)" % [roundi(1000.0 / avg_ms), avg_ms, _worst_ms])
		# Draw calls: cuántas veces le pedimos a la GPU "dibuja esto". Es el
		# número que más crece con muchos enemigos (cada sprite = 1 llamada).
		var draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var gpu: float = Graphics.gpu_ms()
		var gpu_text: String = "GPU %.1f ms · " % gpu if gpu > 0.0 else ""
		lines.append("%sdraw calls %d" % [gpu_text, draws])
		var size: Vector2i = Graphics.internal_size()
		var res_text: String = "3D %dx%d (x%d)" % [size.x, size.y, Graphics.pixel_factor()] \
			if Graphics.is_pixelated() else "3D nativo %dx%d" % [size.x, size.y]
		lines.append("%s · %s" % [res_text, Graphics.current_renderer()])
		lines.append("v%s" % ProjectSettings.get_setting("application/config/version"))
	text = "\n".join(lines)
	_elapsed = 0.0
	_frames = 0
	_worst_ms = 0.0
