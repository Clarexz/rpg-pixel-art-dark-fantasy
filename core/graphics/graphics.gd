extends CanvasLayer
## Autoload "Graphics": el pipeline pixel art de todo el juego.
##
## Cómo funciona (ver docs/pipeline-pixel-art.md):
## 1. Apagamos el 3D de la ventana principal (root.disable_3d).
## 2. Un SubViewport chiquito (p. ej. 216x480) dibuja el MISMO mundo 3D con una
##    cámara espejo que copia a la cámara del jugador en cada frame.
## 3. Esa imagen chiquita se estira a pantalla completa con filtro "nearest"
##    (sin suavizar), así cada píxel se vuelve un cuadrito nítido.
## 4. El HUD y los botones se siguen dibujando a resolución completa encima.
##
## Analogía web: es como dibujar en un <canvas width=216 height=480> y
## mostrarlo con CSS `width:100%; image-rendering: pixelated`, mientras el
## resto del DOM (los botones) sigue nítido.

signal changed

const RENDERER_OVERRIDE_PATH: String = "user://renderer_override.cfg"
const RESUME_PATH: String = "user://benchmark_resume"
const BENCHMARK_SCENE: String = "res://world/benchmark/benchmark.tscn"
const RENDERER_NAMES: Dictionary = {
	"mobile": "Mobile (Vulkan)",
	"gl_compatibility": "Compatibility (OpenGL)",
}

var settings: GraphicsSettings

var _sub: SubViewport
var _cam: Camera3D
var _rect: TextureRect
var _factor: int = 1


func _ready() -> void:
	layer = -100  # debajo de todo: el HUD y los botones van encima
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Correr DESPUÉS de que el jugador movió su cámara en este frame.
	process_priority = 1000
	settings = GraphicsSettings.load_or_default()

	_sub = SubViewport.new()
	_sub.name = "World3DView"
	# Mismo mundo que la ventana principal: no duplicamos nada, solo otra cámara.
	_sub.world_3d = get_tree().root.world_3d
	_sub.msaa_3d = Viewport.MSAA_DISABLED
	_sub.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_sub.audio_listener_enable_3d = false
	add_child(_sub)
	_cam = Camera3D.new()
	_sub.add_child(_cam)
	_cam.current = true

	_rect = TextureRect.new()
	_rect.texture = _sub.get_texture()
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_rect)

	RenderingServer.viewport_set_measure_render_time(_sub.get_viewport_rid(), true)
	RenderingServer.viewport_set_measure_render_time(get_tree().root.get_viewport_rid(), true)
	get_tree().root.size_changed.connect(apply)
	apply()

	if FileAccess.file_exists(RESUME_PATH):
		# Venimos de reiniciar la app a mitad de la prueba de rendimiento.
		DirAccess.remove_absolute(RESUME_PATH)
		get_tree().change_scene_to_file.call_deferred(BENCHMARK_SCENE)


## Aplica settings.pixel_height. Se llama sola al cambiar el tamaño de ventana.
func apply() -> void:
	var root: Window = get_tree().root
	var pixelated: bool = settings.pixel_height > 0
	root.disable_3d = pixelated
	_rect.visible = pixelated
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS if pixelated else SubViewport.UPDATE_DISABLED
	if pixelated:
		var window: Vector2i = root.size
		# Factor ENTERO: cada píxel del mundo mide exactamente N×N píxeles
		# reales. Con factores con decimales unas columnas saldrían más anchas.
		_factor = maxi(1, roundi(float(window.y) / float(settings.pixel_height)))
		_sub.size = Vector2i(ceili(float(window.x) / _factor), ceili(float(window.y) / _factor))
		# El rect vive en unidades de UI (720 de ancho), no en píxeles reales.
		var ui_scale: float = float(window.x) / root.get_visible_rect().size.x
		_rect.position = Vector2.ZERO
		_rect.size = Vector2(_sub.size * _factor) / ui_scale
	_mirror_camera()
	changed.emit()


func _process(_delta: float) -> void:
	if settings.pixel_height > 0:
		_mirror_camera()


## Copia la cámara activa de la escena (la del jugador) a nuestra cámara.
func _mirror_camera() -> void:
	var src: Camera3D = get_tree().root.get_camera_3d()
	if src == null:
		return
	_cam.global_transform = src.global_transform
	_cam.projection = src.projection
	_cam.fov = src.fov
	_cam.size = src.size
	_cam.near = src.near
	_cam.far = src.far
	_cam.keep_aspect = src.keep_aspect
	_cam.h_offset = src.h_offset  # sacudida de cámara
	_cam.v_offset = src.v_offset
	_cam.cull_mask = src.cull_mask
	_cam.environment = src.environment
	_cam.attributes = src.attributes


func is_pixelated() -> bool:
	return settings.pixel_height > 0


## Resolución a la que se dibuja el mundo 3D ahora mismo.
func internal_size() -> Vector2i:
	return _sub.size if is_pixelated() else get_tree().root.size


## Cuántos píxeles reales mide cada píxel del mundo (de lado).
func pixel_factor() -> int:
	return _factor if is_pixelated() else 1


## Milisegundos que tardó la GPU en dibujar el mundo 3D (0 si el driver no lo
## reporta). Sirve para ver cuánto "margen" queda aunque los FPS digan 60.
func gpu_ms() -> float:
	var rid: RID = _sub.get_viewport_rid() if is_pixelated() else get_tree().root.get_viewport_rid()
	return RenderingServer.viewport_get_measured_render_time_gpu(rid)


func set_pixel_height(height: int) -> void:
	settings.pixel_height = height
	apply()


# --- Renderer ---------------------------------------------------------------

## Renderer con el que arrancó la app ("mobile" o "gl_compatibility").
func current_renderer() -> String:
	return RenderingServer.get_current_rendering_method()


## Renderer que se usará la PRÓXIMA vez que abras la app.
func next_renderer() -> String:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(RENDERER_OVERRIDE_PATH) == OK:
		return cfg.get_value("rendering", "renderer/rendering_method", "mobile")
	return ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", "mobile")


## El renderer no se puede cambiar con el juego abierto: Godot lo elige al
## arrancar. Escribimos un archivo que project.godot manda leer
## (application/config/project_settings_override) y pedimos reabrir la app.
## Analogía web: cambiar una variable de entorno y reiniciar el servidor.
func request_renderer(method: String) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("rendering", "renderer/rendering_method", method)
	# En Android manda la variante ".mobile" de la opción, así que van las dos.
	cfg.set_value("rendering", "renderer/rendering_method.mobile", method)
	var err: Error = cfg.save(RENDERER_OVERRIDE_PATH)
	if err != OK:
		push_warning("No se pudo guardar el renderer: %s" % error_string(err))


static func renderer_name(method: String) -> String:
	return RENDERER_NAMES.get(method, method)


## Cierra la app para que el cambio de renderer surta efecto. En la compu
## (editor) se reinicia sola; en Android hay que volver a abrirla a mano.
func restart_app() -> void:
	if not OS.has_feature("mobile"):
		OS.set_restart_on_exit(true)
	get_tree().quit()
