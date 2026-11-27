class_name DuelUI
extends Control
## Pantalla del duelo, pensada para UN pulgar en vertical:
##
##   ┌───────────────────┐
##   │ Lobo   [████░░]   │  arriba: enemigo y lo que dice (solo se lee)
##   │ "La última vez…"  │
##   │                   │
##   │   (!)   ◯→        │  centro: el rival y la flecha + aro de su ataque
##   │                   │
##   │ PV ███  PA ●●  PM │  abajo: tus barras
##   │      [Volver][Fin]│
##   │  [Bloq][Bloq][Bloq]│  la cuadrícula 2x3 (o el menú 2x2) pegada a la
##   │  [Atac][Atac][Atac]│  orilla del lado de tu mano
##   └───────────────────┘
##
## No conoce las reglas: muestra lo que Duel le pide y avisa con `event`
## qué tocaste ("signal up"). Los botones se crean por código, como un
## componente que hace `items.map(...)`.

signal event(kind: StringName, value: int)

## Qué fila(s) de la cuadrícula se pueden tocar.
enum Rows { NONE, TOP, BOTTOM, BOTH }

const CELL_TEXT: Array[String] = [
	"Bloquear\n< Izq", "Bloquear\nCentro", "Bloquear\nDer >",
	"Atacar\n< Izq", "Atacar\nCentro", "Atacar\nDer >",
]
const COLOR_GUARD: Color = CombatStyle.GUARD
const COLOR_ATTACK: Color = CombatStyle.ATTACK
const COLOR_NEUTRAL: Color = CombatStyle.NEUTRAL
const COLOR_MENU: Color = CombatStyle.ITEMS
## Abanico del menú del turno: [etiqueta, color, ancho, alto], de abajo (0)
## hacia arriba (3). El tamaño es la importancia.
const FAN: Array[Dictionary] = [
	{"label": "CUERPO A\nCUERPO", "color": CombatStyle.ATTACK, "w": 320.0, "h": 108.0},
	{"label": "HECHIZOS", "color": CombatStyle.SPELL, "w": 270.0, "h": 88.0},
	{"label": "ITEMS", "color": CombatStyle.ITEMS, "w": 215.0, "h": 74.0},
	{"label": "HUIR", "color": CombatStyle.FLEE, "w": 170.0, "h": 62.0},
]
## Margen en la orilla de la mano para que la inclinación no se recorte.
const HAND_MARGIN: float = 22.0
const FAN_GAP: float = 12.0
const FAN_MARGIN: float = 20.0
const FAN_BOTTOM: float = 24.0
const FAN_SLIDE: Vector2 = Vector2(80, 40)
const FAN_TIME: float = 0.18
const FAN_STAGGER: float = 0.04
const CLUSTER_W: float = 480.0
const CELL_H: float = 124.0
const GAP: float = 10.0
## Después de cambiar los botones, ignorar toques un instante: si no, el
## mismo pulgar que tocó "Hechizos" "toca" el botón nuevo que aparece debajo.
const SWAP_LOCK_MS: int = 150

var left_handed: bool = false

var _rival_name: Label
var _rival_bar: ProgressBar
var _status: Label
var _dialog: Label
var _prompt: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _pa_bar: ProgressBar
var _pa_label: Label
var _pm_bar: ProgressBar
var _pm_label: Label
var _song: SongDisplay
var _util_row: HBoxContainer
var _back_button: Button
var _end_button: Button
var _cluster_row: HBoxContainer
var _cluster: GridContainer
var _fan: Control
var _telegraph: TelegraphView
var _flash: ColorRect
var _banner: Label
var _buttons: Dictionary = {}  # "kind:value" -> Button
var _lock_until: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Theme.new()
	theme.default_font_size = 28
	_build()
	hide()


# --- API que usa Duel -------------------------------------------------------

func set_rival(rival_name: String, hp: int, max_hp: int) -> void:
	_rival_name.text = rival_name
	_rival_bar.max_value = max_hp
	_rival_bar.value = hp


func set_stats(hp: int, max_hp: int, pa: int, max_pa: int, pm: int, max_pm: int) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_label.text = "PV %d" % hp
	_pa_bar.max_value = max_pa
	_pa_bar.value = pa
	_pa_label.text = "PA %d" % pa
	_pm_bar.max_value = max_pm
	_pm_bar.value = pm
	_pm_label.text = "PM %d" % pm


## Estado del enemigo debajo de su barra (p. ej. "Cargando..."). "" = nada.
func status(text: String) -> void:
	_status.text = text
	_status.visible = not text.is_empty()


func say(text: String) -> void:
	_dialog.text = text


func prompt(text: String) -> void:
	_prompt.text = text


## Menú principal del turno: 4 botones inclinados en abanico diagonal, el más
## grande abajo y pegado a la orilla de tu mano.
## flee_hint = qué tan fácil es huir según tu piedra ("fácil", "difícil"...).
func show_menu(flee_hint: String = "") -> void:
	_set_util(false, false)
	_fill(3, [])
	_cluster_row.custom_minimum_size.y = _fan_height()
	var skew: float = CombatStyle.skew_for(left_handed)
	for i: int in FAN.size():
		var d: Dictionary = FAN[i]
		var b: Button = Button.new()
		b.text = d.label
		if i == 3 and not flee_hint.is_empty():
			b.text = "HUIR\n(%s)" % flee_hint
		var h: float = d.h
		b.size = Vector2(d.w, h)
		b.focus_mode = Control.FOCUS_NONE
		var fs: int = roundi(h * 0.32)
		if i == 3 and not flee_hint.is_empty():
			fs = roundi(h * 0.27)
		CombatStyle.style_button(b, d.color, fs, true, skew)
		b.add_theme_constant_override("outline_size", 5)
		# Márgenes verticales mínimos para que el texto no estire el botón.
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			var box: StyleBoxFlat = b.get_theme_stylebox(state) as StyleBoxFlat
			box.content_margin_top = 0.0
			box.content_margin_bottom = 0.0
		b.button_down.connect(_emit.bind(&"menu", i))
		_fan.add_child(b)
		_buttons["menu:%d" % i] = b
	_layout_fan(true)


## Alto total de la pila del abanico.
func _fan_height() -> float:
	var total: float = FAN_BOTTOM
	for d: Dictionary in FAN:
		total += float(d.h) + FAN_GAP
	return total - FAN_GAP


## Coloca los botones del abanico (escalonados a lo largo de la inclinación).
## animate = entran deslizándose desde la orilla de la mano.
func _layout_fan(animate: bool) -> void:
	var buttons: Array[Button] = []
	for child: Node in _fan.get_children():
		if not child.is_queued_for_deletion():
			buttons.append(child as Button)
	if buttons.size() != FAN.size():
		return
	# Desplazamiento a lo largo de la diagonal: la distancia vertical entre
	# centros por la inclinación (la pila se lee como un solo paralelogramo).
	var shifts: Array[float] = []
	var y_centers: Array[float] = []
	var y: float = size.y - FAN_BOTTOM
	for i: int in buttons.size():
		var h: float = buttons[i].size.y
		y -= h
		y_centers.append(y + h * 0.5)
		y -= FAN_GAP
	for i: int in buttons.size():
		shifts.append((y_centers[0] - y_centers[i]) * CombatStyle.SKEW)
	# Lo que sobresale la caja del botón de abajo por la inclinación (la mitad
	# del alto por SKEW): se descuenta del margen para no recortar nada.
	var overhang: float = buttons[0].size.y * CombatStyle.SKEW * 0.5
	var side: float = -1.0 if left_handed else 1.0
	for i: int in buttons.size():
		var b: Button = buttons[i]
		# Borde del lado de la mano: cada botón de arriba se corre hacia el
		# centro de la pantalla, siguiendo la diagonal.
		var edge: float = size.x - FAN_MARGIN - overhang - shifts[i]
		var x: float = edge - b.size.x
		if left_handed:
			x = size.x - edge
		b.position = Vector2(x, y_centers[i] - b.size.y * 0.5)
		if animate:
			var final_pos: Vector2 = b.position
			b.position = final_pos + FAN_SLIDE * Vector2(side, 1.0)
			b.modulate.a = 0.0
			var tween: Tween = b.create_tween().set_parallel()
			tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tween.tween_property(b, "position", final_pos, FAN_TIME).set_delay(FAN_STAGGER * i)
			tween.tween_property(b, "modulate:a", 1.0, FAN_TIME).set_delay(FAN_STAGGER * i)


## La cuadrícula 2x3. neutral = colores iguales (para tocar canciones).
func show_grid(rows: Rows, back: bool, end: bool, neutral: bool = false) -> void:
	_set_util(back, end)
	var defs: Array[Dictionary] = []
	for cell: int in 6:
		var color: Color = COLOR_NEUTRAL if neutral else (COLOR_GUARD if cell < 3 else COLOR_ATTACK)
		defs.append(_def(CELL_TEXT[cell], &"cell", cell, color))
	_fill(3, defs)
	set_rows(rows)


func set_rows(rows: Rows) -> void:
	for cell: int in 6:
		var top: bool = cell < 3
		var on: bool = rows == Rows.BOTH or (rows == Rows.TOP and top) or (rows == Rows.BOTTOM and not top)
		var b: Button = _buttons.get("cell:%d" % cell)
		if b:
			b.disabled = not on


## spells: [{name, cost, ...}]. Los que no alcanzan de PM se ven apagados.
func show_spells(spells: Array, pm: int) -> void:
	_set_util(true, false)
	var defs: Array[Dictionary] = []
	for i: int in spells.size():
		var s: Dictionary = spells[i]
		var d: Dictionary = _def("%s\n%d PM" % [s.name, s.cost], &"spell", i, COLOR_GUARD)
		d.disabled = pm < int(s.cost)
		defs.append(d)
	_fill(2, defs)


## items: [{name, desc, count}].
func show_items(items: Array) -> void:
	_set_util(true, false)
	var defs: Array[Dictionary] = []
	for i: int in items.size():
		var it: Dictionary = items[i]
		var d: Dictionary = _def("%s x%d\n%s" % [it.name, it.count, it.desc], &"item", i, COLOR_MENU)
		d.disabled = int(it.count) <= 0
		defs.append(d)
	_fill(2, defs)


func set_back_visible(on: bool) -> void:
	_back_button.visible = on


func show_song(song: Array, done: int, hints: bool) -> void:
	_song.song = song
	_song.done = done
	_song.hints = hints
	_song.show()
	_song.queue_redraw()


func hide_song() -> void:
	_song.hide()


## feint = aviso de finta (aro morado con "?"): va a cambiar de lado.
func telegraph(side: int, windup: float, perfect_window: float, feint: bool = false) -> void:
	_telegraph.start(side, windup, perfect_window, feint)


## La finta cambia de lado sin reiniciar el aro.
func retarget(side: int) -> void:
	_telegraph.retarget(side)


## Antes de un combo: muestra los lados en orden (1, 2, 3).
func preview(sides: Array[int]) -> void:
	_telegraph.preview(sides)


func clear_telegraph() -> void:
	_telegraph.stop()


## Ilumina un botón un instante (para que se note qué tocaste).
func mark(kind: StringName, value: int, color: Color = Color.WHITE) -> void:
	var b: Button = _buttons.get("%s:%d" % [kind, value])
	if b == null:
		return
	b.modulate = color * 1.6
	create_tween().tween_property(b, "modulate", Color.WHITE, 0.25)


## Texto que sube y se desvanece, a la altura del lado indicado (0..2).
func float_text(text: String, color: Color, side: int = 1) -> void:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.reset_size()
	var x: float = size.x * [0.27, 0.5, 0.73][clampi(side, 0, 2)] - l.size.x * 0.5
	l.position = Vector2(clampf(x, 8.0, size.x - l.size.x - 8.0), size.y * 0.36)
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(l, "position:y", l.position.y - 110.0, 0.9).set_ease(Tween.EASE_OUT)
	tween.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tween.chain().tween_callback(l.queue_free)


func flash(color: Color, strength: float = 0.35) -> void:
	_flash.color = color
	_flash.modulate.a = strength
	create_tween().tween_property(_flash, "modulate:a", 0.0, 0.3)


func banner(text: String) -> void:
	_banner.text = text
	_banner.visible = not text.is_empty()


## Para las pruebas: el botón de cierto evento (o null).
func button_for(kind: StringName, value: int) -> Button:
	return _buttons.get("%s:%d" % [kind, value])


# --- Construcción -------------------------------------------------------------

func _build() -> void:
	_telegraph = TelegraphView.new()
	_telegraph.set_anchors_preset(Control.PRESET_FULL_RECT)
	_telegraph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_telegraph)

	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	# Arriba: rival.
	var top: PanelContainer = PanelContainer.new()
	top.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.55), 14))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var top_box: VBoxContainer = VBoxContainer.new()
	top.add_child(top_box)
	_rival_name = Label.new()
	CombatStyle.style_title_label(_rival_name, 34, 8)
	top_box.add_child(_rival_name)
	_rival_bar = _bar(Color(0.75, 0.2, 0.25), 22)
	top_box.add_child(_rival_bar)
	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	_status.add_theme_font_size_override("font_size", 28)
	_status.hide()
	top_box.add_child(_status)
	_dialog = Label.new()
	_dialog.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog.add_theme_color_override("font_color", Color(1, 0.88, 0.6))
	_dialog.add_theme_font_size_override("font_size", 28)
	top_box.add_child(_dialog)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(spacer)

	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CombatStyle.style_title_label(_banner, 64, 14)
	_banner.hide()
	root.add_child(_banner)

	# Abajo: tus barras.
	var stats: PanelContainer = PanelContainer.new()
	stats.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.55), 12))
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stats)
	var stats_box: VBoxContainer = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 6)
	stats.add_child(stats_box)
	_hp_label = Label.new()
	_hp_bar = _bar(Color(0.8, 0.25, 0.25), 22)
	stats_box.add_child(_stat_row(_hp_label, _hp_bar))
	_pa_label = Label.new()
	_pa_bar = _bar(Color(0.95, 0.6, 0.15), 18)
	stats_box.add_child(_stat_row(_pa_label, _pa_bar))
	_pm_label = Label.new()
	_pm_bar = _bar(Color(0.3, 0.55, 1.0), 18)
	stats_box.add_child(_stat_row(_pm_label, _pm_bar))
	_prompt = Label.new()
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.add_theme_font_size_override("font_size", 26)
	stats_box.add_child(_prompt)

	_song = SongDisplay.new()
	_song.custom_minimum_size = Vector2(0, 96)
	_song.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_song.hide()
	root.add_child(_song)

	_util_row = HBoxContainer.new()
	_util_row.add_theme_constant_override("separation", int(GAP))
	root.add_child(_util_row)
	_back_button = _make_button("Volver", COLOR_NEUTRAL, Vector2(180, 84))
	_back_button.button_down.connect(_emit.bind(&"back", 0))
	_end_button = _make_button("Terminar turno", COLOR_NEUTRAL, Vector2(290, 84))
	_end_button.button_down.connect(_emit.bind(&"end", 0))

	_cluster_row = HBoxContainer.new()
	root.add_child(_cluster_row)
	_cluster = GridContainer.new()
	_cluster.add_theme_constant_override("h_separation", int(GAP))
	_cluster.add_theme_constant_override("v_separation", int(GAP))

	var bottom_pad: Control = Control.new()
	bottom_pad.custom_minimum_size = Vector2(0, 24)
	bottom_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom_pad)

	# Abanico del menú: encima de todo salvo el destello.
	_fan = Control.new()
	_fan.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fan)
	resized.connect(_layout_fan.bind(false))

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	add_child(_flash)
	apply_hand()


## Pega los botones a la orilla de tu mano (derecha, o izquierda en zurdo).
func apply_hand() -> void:
	for row: HBoxContainer in [_util_row, _cluster_row]:
		for child: Node in row.get_children():
			row.remove_child(child)
	var util_items: Array[Control] = [_back_button, _end_button]
	_pack(_util_row, util_items)
	var cluster_items: Array[Control] = [_cluster]
	_pack(_cluster_row, cluster_items)


func _pack(row: HBoxContainer, items: Array[Control]) -> void:
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin: Control = Control.new()
	margin.custom_minimum_size = Vector2(HAND_MARGIN, 0)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not left_handed:
		row.add_child(spacer)
	else:
		row.add_child(margin)
	for item: Control in items:
		row.add_child(item)
	if left_handed:
		row.add_child(spacer)
	else:
		row.add_child(margin)


func _def(text: String, kind: StringName, value: int, color: Color) -> Dictionary:
	return {"text": text, "kind": kind, "value": value, "color": color, "disabled": false}


func _fill(columns: int, defs: Array[Dictionary]) -> void:
	for child: Node in _cluster.get_children():
		child.queue_free()
	_buttons.clear()
	for child: Node in _fan.get_children():
		child.queue_free()
	_cluster_row.custom_minimum_size.y = 0.0
	_buttons["back:0"] = _back_button
	_buttons["end:0"] = _end_button
	_cluster.columns = columns
	_lock_until = Time.get_ticks_msec() + SWAP_LOCK_MS
	var w: float = (CLUSTER_W - GAP * (columns - 1)) / columns
	for d: Dictionary in defs:
		var b: Button = _make_button(d.text, d.color, Vector2(w, CELL_H))
		b.disabled = d.disabled
		# button_down = reacciona al TOCAR, no al soltar: se siente inmediato.
		b.button_down.connect(_emit.bind(d.kind as StringName, d.value as int))
		_cluster.add_child(b)
		_buttons["%s:%d" % [d.kind, d.value]] = b


func _emit(kind: StringName, value: int) -> void:
	if Time.get_ticks_msec() < _lock_until:
		return
	event.emit(kind, value)


func _set_util(back: bool, end: bool) -> void:
	_back_button.visible = back
	_end_button.visible = end


func _make_button(text: String, color: Color, min_size: Vector2) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	CombatStyle.style_button(b, color, 26, false, CombatStyle.skew_for(left_handed))
	return b


func _box(color: Color, radius: int) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(10)
	s.border_color = Color(1, 1, 1, 0.25)
	s.set_border_width_all(2)
	return s


func _bar(color: Color, height: float) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(6)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.08, 0.12)
	bg.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	return bar


func _stat_row(label: Label, bar: ProgressBar) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	label.custom_minimum_size = Vector2(110, 0)
	row.add_child(label)
	row.add_child(bar)
	return row
