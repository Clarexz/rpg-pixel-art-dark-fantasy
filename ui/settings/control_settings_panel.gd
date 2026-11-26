class_name ControlSettingsPanel
extends PanelContainer
## Panel de ajustes de controles, para afinar la sensibilidad en el celular
## mientras juegas. Pausa el juego mientras está abierto.
##
## Las filas se generan desde la lista ROWS en vez de dibujarlas a mano en la
## escena. Analogía web: hacer `ROWS.map(row => <Slider {...row} />)`.

signal closed
## Pide cambiar entre la zona principal y el campo de pruebas.
signal zone_switch_requested

## [propiedad del Resource, texto, mínimo, máximo, paso]. Sin mínimo = checkbox.
## [propiedad, texto, [opciones]] = lista desplegable.
const ROWS: Array = [
	["move_mode", "Modo de movimiento", ["Una mano: libre", "Una mano: por casillas", "Dos pulgares (v0.1)"]],
	["left_handed", "Modo zurdo (botones a la izquierda)"],
	["tank_turn_speed", "Velocidad de giro (una mano)", 60.0, 300.0, 5.0],
	["show_song_hints", "Mostrar las notas de los hechizos"],
	["look_sensitivity", "Sensibilidad al mirar", 0.05, 1.0, 0.01],
	["vertical_ratio", "Sensibilidad vertical (x)", 0.2, 2.0, 0.05],
	["invert_y", "Invertir eje vertical"],
	["fov", "Campo de visión (°)", 60.0, 110.0, 1.0],
	["controls_scale", "Tamaño de los controles", 0.7, 1.4, 0.05],
	["joystick_deadzone", "Zona muerta del joystick", 0.0, 0.5, 0.01],
	["joystick_floating", "Joystick aparece donde tocas"],
	["haptics_enabled", "Vibración"],
	["haptic_ms", "Fuerza de vibración (ms)", 5.0, 80.0, 1.0],
]

var settings: ControlSettings
## Id de la zona cargada (lo pone World al abrir el panel).
var current_zone: StringName = &""

@onready var _rows: VBoxContainer = %Rows
@onready var _close_button: Button = %CloseButton
@onready var _reset_button: Button = %ResetButton


func _ready() -> void:
	# Seguir funcionando aunque el árbol esté en pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_close_button.pressed.connect(close)
	_reset_button.pressed.connect(_reset)
	hide()


func open() -> void:
	_build_rows()
	show()
	get_tree().paused = true


func close() -> void:
	hide()
	get_tree().paused = false
	closed.emit()


func _reset() -> void:
	var defaults: ControlSettings = load(ControlSettings.DEFAULT_PATH)
	for row: Array in ROWS:
		settings.set(row[0], defaults.get(row[0]))
	_build_rows()


func _build_rows() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)  # fuera ya, para que los nombres no choquen
		child.queue_free()
	for row: Array in ROWS:
		var prop: String = row[0]
		if row.size() == 2:
			var check: CheckButton = CheckButton.new()
			check.text = row[1]
			check.button_pressed = settings.get(prop)
			check.toggled.connect(func(on: bool) -> void: settings.set(prop, on))
			_rows.add_child(check)
			continue
		if row.size() == 3:
			var options_title: Label = Label.new()
			options_title.text = row[1]
			_rows.add_child(options_title)
			var options: OptionButton = OptionButton.new()
			options.custom_minimum_size.y = 64
			for option: String in row[2]:
				options.add_item(option)
			options.selected = settings.get(prop)
			options.item_selected.connect(func(index: int) -> void: settings.set(prop, index))
			_rows.add_child(options)
			continue
		var title: Label = Label.new()
		_rows.add_child(title)
		var slider: HSlider = HSlider.new()
		slider.min_value = row[2]
		slider.max_value = row[3]
		slider.step = row[4]
		slider.value = settings.get(prop)
		slider.custom_minimum_size.y = 56
		_rows.add_child(slider)
		var update_title: Callable = func(value: float) -> void:
			var shown: String = str(int(value)) if row[4] >= 1.0 else "%.2f" % value
			if prop == "controls_scale":
				shown = "%d%%" % roundi(value * 100.0)
			title.text = "%s: %s" % [row[1], shown]
		update_title.call(slider.value)
		slider.value_changed.connect(func(value: float) -> void:
			# int para las propiedades enteras (haptic_ms), float para el resto.
			settings.set(prop, int(value) if typeof(settings.get(prop)) == TYPE_INT else value)
			update_title.call(value))
	_build_zone_rows()
	_build_graphics_rows()


## Sección "Zona": ir al campo de pruebas (nivel gris) y volver.
func _build_zone_rows() -> void:
	var header: Label = Label.new()
	header.text = "— Zona —"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rows.add_child(header)
	var go: Button = Button.new()
	go.name = "ZoneSwitchButton"
	go.text = "Volver a la Hondonada de ceniza" if current_zone == &"greybox" \
			else "Ir al campo de pruebas (nivel gris)"
	go.custom_minimum_size.y = 80
	go.pressed.connect(func() -> void:
		close()
		zone_switch_requested.emit())
	_rows.add_child(go)


## Sección "Gráficos y rendimiento". Estos ajustes viven en el autoload
## Graphics (no en ControlSettings) y se guardan al momento.
func _build_graphics_rows() -> void:
	var header: Label = Label.new()
	header.text = "— Gráficos y rendimiento —"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rows.add_child(header)

	var gs: GraphicsSettings = Graphics.settings
	var res_title: Label = Label.new()
	res_title.text = "Resolución del mundo 3D"
	_rows.add_child(res_title)
	var res: OptionButton = OptionButton.new()
	res.custom_minimum_size.y = 64
	for name: String in GraphicsSettings.PIXEL_NAMES:
		res.add_item(name)
	res.selected = maxi(0, GraphicsSettings.PIXEL_HEIGHTS.find(gs.pixel_height))
	res.item_selected.connect(func(index: int) -> void:
		Graphics.set_pixel_height(GraphicsSettings.PIXEL_HEIGHTS[index])
		gs.save())
	_rows.add_child(res)

	var perf: CheckButton = CheckButton.new()
	perf.text = "Monitor de rendimiento completo"
	perf.button_pressed = gs.show_perf
	perf.toggled.connect(func(on: bool) -> void:
		gs.show_perf = on
		gs.save())
	_rows.add_child(perf)

	var methods: Array[String] = ["mobile", "gl_compatibility"]
	var rend_title: Label = Label.new()
	rend_title.text = "Renderer (ahora: %s)" % Graphics.renderer_name(Graphics.current_renderer())
	_rows.add_child(rend_title)
	var rend: OptionButton = OptionButton.new()
	rend.custom_minimum_size.y = 64
	for m: String in methods:
		rend.add_item(Graphics.renderer_name(m))
	rend.selected = maxi(0, methods.find(Graphics.next_renderer()))
	_rows.add_child(rend)
	var rend_note: Label = Label.new()
	rend_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rend_note.add_theme_font_size_override("font_size", 24)
	_rows.add_child(rend_note)
	var update_note: Callable = func() -> void:
		var pending: bool = Graphics.next_renderer() != Graphics.current_renderer()
		rend_note.text = "Cierra la app y vuelve a abrirla para usar el renderer nuevo." if pending else ""
	update_note.call()
	rend.item_selected.connect(func(index: int) -> void:
		Graphics.request_renderer(methods[index])
		update_note.call())

	var bench: Button = Button.new()
	bench.text = "Prueba de rendimiento (≈1 min)"
	bench.custom_minimum_size.y = 80
	bench.pressed.connect(func() -> void:
		close()
		get_tree().change_scene_to_file(Graphics.BENCHMARK_SCENE))
	_rows.add_child(bench)
