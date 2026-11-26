class_name ControlSettings
extends Resource
## Ajustes de controles táctiles. Es un Resource: datos puros, como un JSON
## tipado. El default vive en default_control_settings.tres (editable desde el
## Inspector) y la copia del jugador se guarda en user://control_settings.tres.
##
## Analogía web: un objeto de preferencias que guardas en localStorage.

const USER_PATH: String = "user://control_settings.tres"
const DEFAULT_PATH: String = "res://player/controls/default_control_settings.tres"

@export_group("Mirar")
## Grados que gira la cámara por cada píxel (de UI) que arrastras el dedo.
@export_range(0.05, 1.0, 0.01) var look_sensitivity: float = 0.25
## Multiplicador del eje vertical (mirar arriba/abajo suele querer menos).
@export_range(0.2, 2.0, 0.05) var vertical_ratio: float = 0.8
@export var invert_y: bool = false
## Campo de visión vertical de la cámara, en grados.
@export_range(60.0, 110.0, 1.0) var fov: float = 80.0

@export_group("Joystick")
## Radio del joystick en píxeles de UI (720 de ancho).
@export_range(60.0, 220.0, 1.0) var joystick_radius: float = 120.0
## Zona muerta: fracción del radio que se ignora (evita deriva).
@export_range(0.0, 0.5, 0.01) var joystick_deadzone: float = 0.12
## true: el joystick aparece donde pones el pulgar. false: fijo en su lugar.
@export var joystick_floating: bool = true
## Empujar el joystick más allá de esta fracción activa correr.
@export_range(0.7, 1.01, 0.01) var sprint_threshold: float = 0.95

@export_group("Vibración")
@export var haptics_enabled: bool = true
## Duración base de una vibración corta, en milisegundos.
@export_range(5, 80, 1) var haptic_ms: int = 20


## Carga la copia del usuario si existe; si no, una copia del default.
static func load_or_default() -> ControlSettings:
	if ResourceLoader.exists(USER_PATH):
		var saved: Resource = ResourceLoader.load(USER_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		if saved is ControlSettings:
			return saved
	var base: ControlSettings = load(DEFAULT_PATH)
	return base.duplicate()


func save() -> void:
	var err: Error = ResourceSaver.save(self, USER_PATH)
	if err != OK:
		push_warning("No se pudieron guardar los ajustes de controles: %s" % error_string(err))


## Vibración corta. strength multiplica la duración (1.0 = haptic_ms).
func pulse(strength: float = 1.0) -> void:
	if not haptics_enabled or not OS.has_feature("mobile"):
		return
	Input.vibrate_handheld(int(haptic_ms * strength))
