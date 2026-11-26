extends Node3D
## Escena principal de la fase 1: nivel gris para probar controles.
##
## Este script es el "padre" que conecta a los hijos entre sí: escucha las
## señales de TouchControls y llama métodos de Player ("call down, signal up").
## Analogía web: el componente contenedor que pasa callbacks entre hermanos.

var _settings: ControlSettings

@onready var _player: Player = $Player
@onready var _touch: TouchControls = $HUD/SafeArea/TouchControls
@onready var _settings_button: Button = %SettingsButton
@onready var _panel: ControlSettingsPanel = $HUD/SettingsPanel
@onready var _feedback: Label = %Feedback

var _feedback_tween: Tween


func _ready() -> void:
	# Un solo objeto de ajustes compartido por todos (como un Context de React).
	_settings = ControlSettings.load_or_default()
	_player.settings = _settings
	_player.apply_settings()
	_touch.settings = _settings
	_panel.settings = _settings
	_touch.queue_redraw()

	_touch.add_blocker(_settings_button)
	_touch.move_changed.connect(_on_move_changed)
	_touch.look_dragged.connect(_player.add_look)
	_touch.action_pressed.connect(_on_action_pressed)
	_touch.action_released.connect(_on_action_released)
	_player.attacked.connect(_on_player_attacked)
	_player.scanned.connect(_on_player_scanned)
	_settings_button.pressed.connect(_open_settings)
	_panel.closed.connect(_on_settings_closed)


func _notification(what: int) -> void:
	# Si la app pierde el foco (llamada, notificación, cambiar de app),
	# pausamos abriendo el panel. Al volver, el jugador decide cuándo seguir.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and not _panel.visible:
		_open_settings()


func _on_move_changed(direction: Vector2, sprint: bool) -> void:
	_player.move_input = direction
	_player.sprinting = sprint


func _on_action_pressed(action: StringName) -> void:
	match action:
		&"attack":
			_player.attack()
			_player.attack_held = true
		&"jump":
			_player.jump()
		&"scan":
			_player.scan()


func _on_action_released(action: StringName) -> void:
	if action == &"attack":
		_player.attack_held = false


func _on_player_attacked(hit_something: bool) -> void:
	_show_feedback("¡Golpe!" if hit_something else "")


func _on_player_scanned(target: Node3D) -> void:
	_show_feedback("" if target else "Nada que leer")


func _open_settings() -> void:
	_touch.release_all()
	_touch.hide()
	_panel.open()


func _on_settings_closed() -> void:
	_settings.save()
	_player.apply_settings()
	_touch.show()
	_touch.queue_redraw()


func _show_feedback(text: String) -> void:
	if text.is_empty():
		return
	_feedback.text = text
	_feedback.modulate.a = 1.0
	if _feedback_tween:
		_feedback_tween.kill()
	_feedback_tween = create_tween()
	_feedback_tween.tween_interval(0.4)
	_feedback_tween.tween_property(_feedback, "modulate:a", 0.0, 0.3)
