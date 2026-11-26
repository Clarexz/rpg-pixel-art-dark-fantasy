class_name GraphicsSettings
extends Resource
## Ajustes de gráficos que el jugador puede cambiar en el celular.
## Se guardan en user://graphics_settings.tres (como localStorage).
##
## El renderer NO vive aquí: se cambia escribiendo un archivo de "override"
## que Godot lee al arrancar (ver Graphics.request_renderer()).

const USER_PATH: String = "user://graphics_settings.tres"

## Resoluciones internas del mundo 3D, en píxeles de ALTO. 0 = nativa (sin
## pixelar). El ancho sale de la forma de la pantalla.
const PIXEL_HEIGHTS: Array[int] = [0, 640, 480, 360, 270]
const PIXEL_NAMES: Array[String] = [
	"Nativa (sin pixelar)",
	"640 px de alto (fino)",
	"480 px de alto (recomendado)",
	"360 px de alto (retro)",
	"270 px de alto (muy retro)",
]

## Alto interno del mundo 3D. Más bajo = más pixelado y más barato para la GPU.
@export var pixel_height: int = 480
## Mostrar el monitor de rendimiento completo (ms, GPU, draw calls).
@export var show_perf: bool = true


static func load_or_default() -> GraphicsSettings:
	if ResourceLoader.exists(USER_PATH):
		var saved: Resource = ResourceLoader.load(USER_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		if saved is GraphicsSettings:
			return saved
	return GraphicsSettings.new()


func save() -> void:
	var err: Error = ResourceSaver.save(self, USER_PATH)
	if err != OK:
		push_warning("No se pudieron guardar los ajustes de gráficos: %s" % error_string(err))
