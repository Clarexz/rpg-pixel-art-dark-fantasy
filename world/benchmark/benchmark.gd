extends Node3D
## Prueba de rendimiento automática (≈1 min). Se abre desde Ajustes.
##
## Para cada resolución del mundo 3D va subiendo la cantidad de enemigos
## billboard (0, 50, 100, 200, 400) y mide unos segundos: FPS promedio, el
## "1% más bajo" (los tirones), ms de GPU y draw calls. Al final dice cuántos
## enemigos aguanta tu celular a 60 y a 30 FPS estables, y te deja copiar los
## resultados para pegarlos en el chat.
##
## Analogía web: un Lighthouse que corre dentro del juego.

const GHOUL: PackedScene = preload("res://world/benchmark/ghoul.tscn")
const WORLD: String = "res://world/world.tscn"
const SAFE_AREA: Script = preload("res://ui/safe_area/safe_area_container.gd")
const OVERLAY: Script = preload("res://ui/hud/debug_overlay.gd")

const HEIGHTS: Array[int] = [0, 640, 480, 360, 270]
const COUNTS: Array[int] = [0, 50, 100, 200, 400]
const WARMUP: float = 0.75
const DURATION: float = 2.5
## Si una medición baja de esto, no tiene caso probar con más enemigos.
const GIVE_UP_FPS: float = 24.0
const AREA: Rect2 = Rect2(-14, -18, 28, 22)  # x, z, ancho, fondo

## Modo rápido para la prueba automática de CI (mide casi nada).
var quick: bool = false
## Resultados de esta corrida (también se guardan en user://).
var results: Dictionary = {}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _sampling: bool = false
var _deltas: PackedFloat32Array = []
var _gpu_sum: float = 0.0
var _draw_sum: float = 0.0
var _time: float = 0.0
var _original_height: int
var _original_vsync: DisplayServer.VSyncMode
var _cancelled: bool = false

@onready var _enemies: Node3D = $Enemies
@onready var _camera: Camera3D = $Camera3D

var _status: Label
var _report: Label
var _scroll: ScrollContainer
var _run_buttons: HBoxContainer
var _end_buttons: VBoxContainer


func _ready() -> void:
	_rng.seed = 1
	seed(1)
	_original_height = Graphics.settings.pixel_height
	_original_vsync = DisplayServer.window_get_vsync_mode()
	_build_ui()
	_run.call_deferred()


func _exit_tree() -> void:
	_restore()


func _process(delta: float) -> void:
	# La cámara se balancea un poco para que no sea una foto fija.
	_time += delta
	_camera.rotation.y = sin(_time * TAU / 6.0) * 0.25
	if _sampling:
		_deltas.append(delta)
		_gpu_sum += Graphics.gpu_ms()
		_draw_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)


func _run() -> void:
	# Sin vsync, los FPS pueden pasar de 60 y vemos cuánto margen queda.
	# Algunos celulares no dejan apagarlo; lo anotamos en el reporte.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var heights: Array[int] = HEIGHTS
	var counts: Array[int] = COUNTS
	if quick:
		heights = [0, 480]
		counts = [0, 50]
	var rows: Array[Dictionary] = []
	var total: int = heights.size() * counts.size()
	var step: int = 0
	for height: int in heights:
		Graphics.set_pixel_height(height)
		for count: int in counts:
			step += 1
			if _cancelled:
				return
			_set_enemy_count(count)
			_status.text = "Midiendo %d/%d: %s, %d enemigos" % [step, total, _height_name(height), count]
			await _wait(0.05 if quick else WARMUP)
			var row: Dictionary = await _measure(0.1 if quick else DURATION)
			row.height = height
			var size: Vector2i = Graphics.internal_size()
			row.size = [size.x, size.y]
			row.count = count
			rows.append(row)
			if row.fps < GIVE_UP_FPS:
				break
	if _cancelled:
		return
	_set_enemy_count(0)
	_restore()
	results = _make_results(rows)
	_save(results)
	_show_report()


func _set_enemy_count(count: int) -> void:
	while _enemies.get_child_count() > count:
		var last: Node = _enemies.get_child(_enemies.get_child_count() - 1)
		_enemies.remove_child(last)
		last.queue_free()
	while _enemies.get_child_count() < count:
		var ghoul: BenchGhoul = GHOUL.instantiate()
		ghoul.bounds = AREA
		ghoul.position = Vector3(
			_rng.randf_range(AREA.position.x, AREA.end.x), 0.0,
			_rng.randf_range(AREA.position.y, AREA.end.y))
		_enemies.add_child(ghoul)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _measure(seconds: float) -> Dictionary:
	_deltas = []
	_gpu_sum = 0.0
	_draw_sum = 0.0
	_sampling = true
	await _wait(seconds)
	_sampling = false
	var n: int = maxi(1, _deltas.size())
	var total: float = 0.0
	for d: float in _deltas:
		total += d
	var sorted: PackedFloat32Array = _deltas.duplicate()
	sorted.sort()
	# "1% más bajo": el frame que es más lento que el 99% de los demás.
	# Si es mucho peor que el promedio, el juego "se traba" aunque el
	# promedio se vea bien.
	var p99: float = sorted[int(0.99 * (sorted.size() - 1))] if sorted.size() > 0 else 1.0
	return {
		"fps": n / maxf(total, 0.0001),
		"low": 1.0 / maxf(p99, 0.0001),
		"gpu": _gpu_sum / n,
		"draws": roundi(_draw_sum / n),
	}


func _restore() -> void:
	if Graphics.settings.pixel_height != _original_height:
		Graphics.set_pixel_height(_original_height)
	DisplayServer.window_set_vsync_mode(_original_vsync)


# --- Resultados -------------------------------------------------------------

static func is_stable(row: Dictionary, target: float) -> bool:
	return row.fps >= target * 0.95 and row.low >= target * 0.8


func _make_results(rows: Array[Dictionary]) -> Dictionary:
	var window: Vector2i = get_tree().root.size
	return {
		"version": ProjectSettings.get_setting("application/config/version"),
		"device": "%s (%s)" % [OS.get_model_name(), OS.get_name()],
		"gpu": "%s · %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()],
		"renderer": Graphics.current_renderer(),
		"screen": "%dx%d @%d Hz" % [window.x, window.y, roundi(DisplayServer.screen_get_refresh_rate())],
		"vsync_off": DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED or quick,
		"rows": rows,
	}


func _save(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(_results_path(data.renderer), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


static func _results_path(renderer: String) -> String:
	return "user://benchmark_%s.json" % renderer


static func _load(renderer: String) -> Dictionary:
	if not FileAccess.file_exists(_results_path(renderer)):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_results_path(renderer)))
	return parsed if parsed is Dictionary else {}


static func _height_name(height: int) -> String:
	return "nativa" if height == 0 else "%d px" % height


## Cuántos enemigos aguantó cada resolución a `target` FPS estables
## (todos los pasos hasta ese número tienen que haber pasado). -1 = ni con 0.
static func _summary(data: Dictionary, target: float) -> Dictionary:
	var best: Dictionary = {}
	var failed: Dictionary = {}
	for row: Dictionary in data.rows:
		var h: int = int(row.height)
		if not best.has(h):
			best[h] = -1
			failed[h] = false
		if failed[h]:
			continue
		if is_stable(row, target):
			best[h] = int(row.count)
		else:
			failed[h] = true
	return best


static func report_text(data: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("Prueba de rendimiento v%s" % data.version)
	lines.append("Celular: %s" % data.device)
	lines.append("GPU: %s" % data.gpu)
	lines.append("Renderer: %s" % data.renderer)
	lines.append("Pantalla: %s · vsync %s" % [data.screen, "apagado" if data.vsync_off else "ENCENDIDO (máx = Hz de pantalla)"])
	lines.append("")
	lines.append("Res 3D | enem | FPS | 1%bajo | GPU ms | draws")
	for row: Dictionary in data.rows:
		var size: Array = row.size
		lines.append("%s (%dx%d) | %d | %d | %d | %.1f | %d" % [
			_height_name(int(row.height)), int(size[0]), int(size[1]), int(row.count),
			roundi(row.fps), roundi(row.low), row.gpu, int(row.draws)])
	lines.append("")
	lines.append("Máx. enemigos con FPS estables:")
	var s60: Dictionary = _summary(data, 60.0)
	var s30: Dictionary = _summary(data, 30.0)
	for h: Variant in s60.keys():
		lines.append("  %s: 60 FPS → %s · 30 FPS → %s" % [
			_height_name(int(h)), _count_text(s60[h]), _count_text(s30.get(h, -1))])
	return "\n".join(lines)


static func _count_text(count: int) -> String:
	if count < 0:
		return "no llega"
	if count == COUNTS[-1]:
		return "%d o más" % count
	return str(count)


func _full_report() -> String:
	var text: String = report_text(results)
	var other: String = _other_renderer()
	var other_data: Dictionary = _load(other)
	if not other_data.is_empty() and other_data.get("version") == results.version:
		text += "\n\n=== Corrida anterior con el otro renderer ===\n" + report_text(other_data)
	return text


func _other_renderer() -> String:
	return "gl_compatibility" if Graphics.current_renderer() == "mobile" else "mobile"


# --- UI (por código, como en DuelUI) ------------------------------------------

func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var safe: MarginContainer = SAFE_AREA.new()
	layer.add_child(safe)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	safe.add_child(box)

	var overlay: Label = OVERLAY.new()
	_style(overlay, 24)
	box.add_child(overlay)
	_status = Label.new()
	_style(_status, 30)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "Preparando prueba de rendimiento..."
	box.add_child(_status)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.hide()
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.04, 0.07, 0.9)
	bg.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", bg)
	_report = Label.new()
	_style(_report, 22)
	_report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_report.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(_report)
	_scroll.add_child(panel)
	box.add_child(_scroll)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)

	_run_buttons = HBoxContainer.new()
	_run_buttons.add_child(_button("Cancelar", _back_to_game))
	box.add_child(_run_buttons)

	_end_buttons = VBoxContainer.new()
	_end_buttons.add_theme_constant_override("separation", 12)
	_end_buttons.add_child(_button("Copiar resultados", _copy))
	_end_buttons.add_child(_button("Probar con el otro renderer", _try_other_renderer))
	_end_buttons.add_child(_button("Volver al juego", _back_to_game))
	_end_buttons.hide()
	box.add_child(_end_buttons)


func _button(text: String, action: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 88)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(action)
	return b


func _style(label: Label, font_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _show_report() -> void:
	_status.text = "¡Listo! Copia los resultados y pégalos en el chat."
	_report.text = _full_report()
	print(_report.text)
	_scroll.show()
	_run_buttons.hide()
	_end_buttons.show()


func _copy() -> void:
	DisplayServer.clipboard_set(_full_report())
	_status.text = "Copiado. Pégalo en el chat del proyecto."


func _try_other_renderer() -> void:
	var other: String = _other_renderer()
	Graphics.request_renderer(other)
	# Al volver a abrir la app, Graphics ve este archivo y arranca la prueba sola.
	var flag: FileAccess = FileAccess.open(Graphics.RESUME_PATH, FileAccess.WRITE)
	if flag:
		flag.store_string(other)
		flag.close()
	_status.text = "La app se va a cerrar. Vuelve a abrirla: la prueba sigue sola con %s." % Graphics.renderer_name(other)
	_end_buttons.hide()
	await _wait(3.0)
	Graphics.restart_app()


func _back_to_game() -> void:
	_cancelled = true
	_sampling = false
	_restore()
	get_tree().change_scene_to_file(WORLD)
