extends Node3D
## Escena principal: nivel gris para probar controles y el combate.
##
## Este script es el "padre" que conecta a los hijos entre sí: escucha las
## señales de los controles y de los enemigos y llama métodos de Player y
## Duel ("call down, signal up").
## Analogía web: el componente contenedor que pasa callbacks entre hermanos.

var _settings: ControlSettings
## La memoria de cada rival, guardada por id.
var _rivals: RivalRegistry
## Tus items (se guardan en el celular).
var _inventory: Inventory
var _stone_timer: float = 0.0

@onready var _player: Player = $Player
@onready var _touch: TouchControls = $HUD/SafeArea/TouchControls
@onready var _one_hand: OneHandControls = $HUD/SafeArea/OneHandControls
@onready var _settings_button: Button = %SettingsButton
@onready var _panel: ControlSettingsPanel = $HUD/SettingsPanel
@onready var _feedback: Label = %Feedback
@onready var _stone_label: Label = %StoneLabel
@onready var _hud: CanvasLayer = $HUD
@onready var _duel: Duel = $Duel
@onready var _transition: PixelateTransition = $Transition

var _feedback_tween: Tween


func _ready() -> void:
	# Un solo objeto de ajustes compartido por todos (como un Context de React).
	_settings = ControlSettings.load_or_default()
	_rivals = RivalRegistry.load_or_new()
	_inventory = Inventory.load_or_new()
	_player.settings = _settings
	_touch.settings = _settings
	_one_hand.settings = _settings
	_panel.settings = _settings

	_touch.add_blocker(_settings_button)
	_one_hand.add_blocker(_settings_button)
	_touch.move_changed.connect(_on_move_changed)
	_touch.look_dragged.connect(_player.add_look)
	_touch.action_pressed.connect(_on_action_pressed)
	_touch.action_released.connect(_on_action_released)
	_one_hand.stick_changed.connect(_on_stick_changed)
	_one_hand.step_requested.connect(_on_step_requested)
	_one_hand.action_pressed.connect(_on_action_pressed)
	_one_hand.action_released.connect(_on_action_released)
	_player.attacked.connect(_on_player_attacked)
	_player.scanned.connect(_on_player_scanned)
	_settings_button.pressed.connect(_open_settings)
	_panel.closed.connect(_on_settings_closed)
	_duel.finished.connect(_on_duel_finished)
	_duel.memory_saved.connect(func(_m: RivalMemory) -> void: _rivals.save())
	for enemy: Node in get_tree().get_nodes_in_group("enemy"):
		(enemy as Enemy).engaged.connect(_on_enemy_engaged)
	apply_mode()


## Muestra los controles del modo elegido en Ajustes (una mano o dos pulgares).
func apply_mode() -> void:
	var one_hand: bool = _settings.is_one_hand()
	_touch.release_all()
	_one_hand.release_all()
	_touch.visible = not one_hand and not _duel.is_active()
	_one_hand.visible = one_hand and not _duel.is_active()
	_one_hand.grid_mode = _settings.move_mode == ControlSettings.MODE_GRID
	_one_hand._layout()
	_player.set_grid_mode(_one_hand.grid_mode)
	_player.apply_settings()
	_touch.queue_redraw()


func _notification(what: int) -> void:
	# Si la app pierde el foco (llamada, notificación, cambiar de app),
	# pausamos abriendo el panel. Al volver, el jugador decide cuándo seguir.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and not _panel.visible:
		_open_settings()


func _process(delta: float) -> void:
	_update_stone(delta)


## La piedra vibra cuando hay un enemigo cerca: más seguido entre más cerca.
func _update_stone(delta: float) -> void:
	var closeness: float = 0.0
	if not _duel.is_active():
		for enemy: Node in get_tree().get_nodes_in_group("enemy"):
			closeness = maxf(closeness, (enemy as Enemy).closeness_to(_player.global_position))
	_stone_label.visible = closeness > 0.0
	if closeness <= 0.0:
		_stone_timer = 0.0
		return
	_stone_timer -= delta
	if _stone_timer <= 0.0:
		_stone_timer = lerpf(1.3, 0.25, closeness)
		_settings.pulse(lerpf(0.6, 1.6, closeness))
		Sfx.play(&"stone", 1.0, lerpf(-18.0, -6.0, closeness))
		_stone_label.modulate.a = 1.0
		create_tween().tween_property(_stone_label, "modulate:a", 0.35, _stone_timer * 0.8)


func _on_enemy_engaged(enemy: Enemy, advantage: StringName) -> void:
	if _duel.is_active() or _panel.visible:
		return
	_touch.release_all()
	_one_hand.release_all()
	_on_move_changed(Vector2.ZERO, false)
	_touch.hide()
	_one_hand.hide()
	_settings_button.hide()
	_stone_label.hide()
	_hud.hide()  # el duelo tiene su propia pantalla
	# Solo los rivales tienen memoria; los enemigos comunes no recuerdan nada.
	var memory: RivalMemory = _rivals.memory_for(enemy.data.id) if enemy.is_rival() else null
	_duel.start(_player, enemy, advantage, _settings, memory, _inventory, _transition)


func _on_duel_finished(_result: StringName) -> void:
	_hud.show()
	_settings_button.show()
	apply_mode()


func _on_move_changed(direction: Vector2, sprint: bool) -> void:
	_player.move_input = direction
	_player.turn_input = 0.0
	_player.sprinting = sprint


func _on_stick_changed(turn: float, forward: float, sprint: bool) -> void:
	_player.turn_input = turn
	_player.move_input = Vector2(0.0, -forward)
	_player.sprinting = sprint


func _on_step_requested(direction: Vector2i) -> void:
	if direction.y != 0:
		_player.grid_step(-direction.y)  # stick arriba (y<0) = adelante
	else:
		_player.grid_turn(direction.x)


func _on_action_pressed(action: StringName) -> void:
	match action:
		&"attack":
			_player.attack()
			# En una mano no hay "mantener para seguir golpeando": un toque, un golpe.
			_player.attack_held = not _settings.is_one_hand()
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
	_one_hand.release_all()
	_touch.hide()
	_one_hand.hide()
	_panel.open()


func _on_settings_closed() -> void:
	_settings.save()
	apply_mode()


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
