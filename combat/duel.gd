class_name Duel
extends CanvasLayer
## Reglas del duelo por turnos (estilo Expedition 33, pero a una mano).
##
## Tu turno: menú Cuerpo a cuerpo / Hechizos / Items / Huir.
## - Cuerpo a cuerpo: fila de abajo = atacar izq/centro/der. Cada golpe
##   cuesta PA; puedes encadenar golpes mientras te alcance. El rival cubre
##   un lado (al azar... hasta que te conoce: ver rivals/rival_tactics.gd).
## - Hechizos: eliges uno y tocas su "canción" (3-4 casillas) en la misma
##   cuadrícula. Cuesta PM. Si la tocas con ritmo parejo, sale más fuerte.
## - Items: poción (PV) o éter (PM). Gasta el turno.
## - Huir: puede fallar.
## Turno del rival: avisa con una flecha de qué lado viene. Bloquea con la
## fila de arriba del mismo lado. Si bloqueas justo antes del golpe
## (bloqueo perfecto) no te hace daño y recuperas PA.
##
## Todo el flujo usa `await` (como async/await en JS): el código se lee en
## orden aunque espere toques del jugador y animaciones.

signal finished(result: StringName)  # &"win", &"lose" o &"fled"
## Ya se actualizó la memoria del rival (el mundo la guarda en disco).
signal memory_saved(memory: RivalMemory)

const PLAYER_MAX_HP: int = 100
const PA_MAX: int = 10
const PA_START: int = 4
const PA_PER_TURN: int = 3
const ATTACK_COST: int = 2
const PERFECT_REFUND: int = 2
const PM_MAX: int = 12
const PM_START: int = 6
const PM_PER_TURN: int = 2
const FIRST_STRIKE_DAMAGE: int = 10
const HIT_DAMAGE: int = 9
const GUARDED_DAMAGE: int = 2
const RIVAL_DAMAGE: int = 12
## Segundos antes del impacto en los que bloquear cuenta como perfecto.
const PERFECT_WINDOW: float = 0.25
const FLEE_CHANCE: float = 0.65
## Tiempo máximo entre notas de una canción.
const NOTE_TIMEOUT: float = 1.6

## Las 4 casillas equipadas. song usa las casillas de la cuadrícula:
## 0 1 2 = fila de arriba (izq, centro, der), 3 4 5 = fila de abajo.
const SPELLS: Array[Dictionary] = [
	{"name": "Fuego", "cost": 4, "song": [3, 1, 5], "kind": &"damage", "power": 20},
	{"name": "Curar", "cost": 4, "song": [4, 1, 4], "kind": &"heal", "power": 25},
	{"name": "Égida", "cost": 3, "song": [0, 2, 1], "kind": &"aegis", "power": 0},
	{"name": "Trueno", "cost": 6, "song": [5, 2, 0, 3], "kind": &"stun", "power": 12},
]
const SIDE_WORD: Array[String] = ["izquierda", "centro", "derecha"]

# Estado visible para las pruebas automáticas.
var phase: StringName = &"idle"
var hp: int = PLAYER_MAX_HP
var pa: int = PA_START
var pm: int = PM_START
var telegraph_side: int = -1
## Momento del impacto del ataque actual del rival (segundos, ver _now()).
var impact_at: float = 0.0
var result: StringName = &""
var stats: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _player: Player
var _rival: RivalCube
var _settings: ControlSettings
var _memory: RivalMemory
## Cómo pelea el rival en ESTE duelo (sale de su memoria al empezar).
var _tactics: RivalTactics
## Lo que va pasando en este duelo; al final se entrega a la memoria.
var _encounter: Encounter
var _transition: PixelateTransition
var _items: Array[Dictionary] = []
var _aegis: bool = false
var _rival_stunned: bool = false
var _token: int = 0

@onready var _ui: DuelUI = $SafeArea/DuelUI


func _ready() -> void:
	layer = 10
	rng.randomize()


func is_active() -> bool:
	return phase != &"idle"


func start(player: Player, rival: RivalCube, advantage: StringName, settings: ControlSettings,
		memory: RivalMemory, transition: PixelateTransition) -> void:
	_player = player
	_rival = rival
	_settings = settings
	_memory = memory
	_transition = transition
	_tactics = RivalTactics.plan(rival.data, memory)
	_encounter = Encounter.new()
	_encounter.rival_id = rival.data.id
	_encounter.advantage = advantage
	hp = PLAYER_MAX_HP
	pa = PA_START
	pm = PM_START
	result = &""
	_aegis = false
	_rival_stunned = false
	stats = {"perfect": 0, "blocked": 0, "hit": 0, "attacks": 0, "spells": 0}
	_items = [
		{"name": "Poción", "desc": "+30 PV", "count": 2},
		{"name": "Éter", "desc": "+6 PM", "count": 1},
	]
	_run(advantage)


# --- Flujo principal -------------------------------------------------------

func _run(advantage: StringName) -> void:
	phase = &"intro"
	await _intro(advantage)
	if advantage == &"rival":
		await _rival_turn()
	while not _is_over():
		await _player_turn()
		if _is_over():
			break
		if _rival_stunned:
			_rival_stunned = false
			_ui.prompt("El cubo está aturdido y pierde su turno.")
			await _wait(0.9)
			continue
		await _rival_turn()
	await _outro()


func _is_over() -> bool:
	if result == &"fled":
		return true
	if _rival.hp <= 0:
		result = &"win"
	elif hp <= 0:
		result = &"lose"
	return result != &""


func _intro(advantage: StringName) -> void:
	_rival.in_combat = true
	_player.controls_enabled = false
	_player.attack_held = false
	Sfx.play(&"engage")
	_settings.pulse(3.0)
	await _transition.cover(0.3)

	# Acomodar la escena "en el lugar": el rival queda enfrente de ti.
	var to_rival: Vector3 = _rival.global_position - _player.global_position
	to_rival.y = 0.0
	var dir: Vector3 = to_rival.normalized() if to_rival.length() > 0.1 else -_player.global_basis.z
	_player.face_direction(dir)
	var spot: Vector3 = _player.global_position + dir * 2.8
	spot.y = _player.global_position.y
	_rival.enter_duel(spot, _player.global_position)
	_rival.view_right = _player.global_basis.x

	_ui.left_handed = _settings.left_handed
	_ui.apply_hand()
	_ui.banner("")
	_ui.hide_song()
	_ui.clear_telegraph()
	var fame: String = Piedra.record.fame_title(_encounter.zone)
	# Saludo según lo que recuerda + lectura de tu piedra (se queda visible).
	_ui.say("%s: \"%s\"\n◆ Piedra: %s." % [_rival.display_name,
			RivalDialogue.greeting(_rival.data, _memory, _tactics, fame),
			Piedra.scan(_rival.data, _memory).text])
	if advantage == &"player":
		_rival.hp = maxi(_rival.hp - FIRST_STRIKE_DAMAGE, 1)
		pa += 2
		_ui.prompt("¡Golpeaste primero! Empiezas tú con +2 PA.")
	else:
		_ui.prompt("¡Te emboscó! Ataca él primero.")
	_refresh()
	_ui.show_menu()
	_ui.set_rows(DuelUI.Rows.NONE)
	_ui.show()
	await _transition.reveal(0.3)
	if advantage == &"player":
		_rival.hurt(1)
		_ui.float_text("-%d" % FIRST_STRIKE_DAMAGE, Color.WHITE, 1)
		Sfx.play(&"hit")
	await _wait(0.7)


func _outro() -> void:
	phase = &"outro"
	_ui.clear_telegraph()
	_ui.hide_song()
	_ui.show_grid(DuelUI.Rows.NONE, false, false)
	match result:
		&"win":
			_rival.die()
			Sfx.play(&"perfect", 0.7)
			_ui.banner("¡VICTORIA!")
			_ui.say("%s: \"%s\"" % [_rival.display_name, RivalDialogue.defeated(_rival.data)])
		&"lose":
			Sfx.play(&"hurt", 0.6)
			_ui.banner("Caíste...")
			_ui.say("%s: \"Vuelve cuando seas más fuerte.\"" % _rival.display_name)
		&"fled":
			_ui.banner("Huiste")
			_ui.say("%s: \"¡Eso, corre!\"" % _rival.display_name)
	_save_encounter()
	await _wait(1.4)
	await _transition.cover(0.3)
	_ui.hide()
	_ui.banner("")
	_rival.leave_duel(result)
	match result:
		&"lose":
			_player.respawn()
		&"fled":
			# Te alejas unos pasos del rival.
			var away: Vector3 = _player.global_basis.z * 3.0
			_player.move_and_collide(away)
	_player.controls_enabled = true
	await _transition.reveal(0.3)
	phase = &"idle"
	finished.emit(result)


# --- Tu turno ---------------------------------------------------------------

func _player_turn() -> void:
	pa = mini(pa + PA_PER_TURN, PA_MAX)
	pm = mini(pm + PM_PER_TURN, PM_MAX)
	_refresh()
	while true:
		phase = &"menu"
		_ui.show_menu()
		_ui.prompt("Tu turno. Elige qué hacer.")
		var ev: Array = await _next_event()
		if ev[0] != &"menu":
			continue
		Sfx.play(&"tick")
		_settings.pulse(0.4)
		var acted: bool = false
		match ev[1]:
			0:
				acted = await _melee()
			1:
				acted = await _spells()
			2:
				acted = await _use_items()
			3:
				acted = await _flee()
		if acted:
			return


func _melee() -> bool:
	phase = &"melee"
	var attacks: int = 0
	_ui.show_grid(DuelUI.Rows.BOTTOM, true, true)
	while true:
		_refresh()
		var can: bool = pa >= ATTACK_COST
		_ui.set_rows(DuelUI.Rows.BOTTOM if can else DuelUI.Rows.NONE)
		if not can:
			if attacks > 0:
				_ui.prompt("Sin PA. Termina tu turno.")
				await _wait(0.6)
				return true
			_ui.prompt("No te alcanzan los PA (%d por golpe)." % ATTACK_COST)
		else:
			_ui.prompt("Ataca por izq/centro/der (%d PA por golpe)." % ATTACK_COST)
		phase = &"melee"
		var ev: Array = await _next_event()
		match ev[0]:
			&"back":
				if attacks == 0:
					return false
			&"end":
				return attacks > 0
			&"cell":
				if ev[1] >= 3 and can:
					attacks += 1
					_ui.set_back_visible(false)
					await _player_attack(ev[1] - 3)
					if _rival.hp <= 0:
						return true
	return true


func _player_attack(side: int) -> void:
	phase = &"busy"
	pa -= ATTACK_COST
	stats.attacks += 1
	_encounter.attack_sides[side] += 1
	_ui.mark(&"cell", side + 3)
	_player.swing(side)
	Sfx.play(&"swing")
	await _wait(0.08)
	var guard: int = _pick_guard()
	if guard == side:
		_rival.hp -= GUARDED_DAMAGE
		_rival.show_guard(side)
		Sfx.play(&"block")
		_settings.pulse(1.0)
		_ui.float_text("¡Lo bloqueó! -%d" % GUARDED_DAMAGE, Color(0.6, 0.8, 1.0), side)
		await _hitstop(0.04)
	else:
		_rival.hp -= HIT_DAMAGE
		_rival.hurt(side)
		Sfx.play(&"hit")
		_settings.pulse(2.2)
		_player.shake(0.03, 0.1)
		_ui.float_text("-%d" % HIT_DAMAGE, Color.WHITE, side)
		await _hitstop(0.07)
	_refresh()
	await _wait(0.18)


## Qué lado cubre el rival. Al principio adivina; cuando ya te conoce
## (memoria), cubre tu lado favorito la mayoría de las veces.
func _pick_guard() -> int:
	return _tactics.pick_guard(rng)


func _spells() -> bool:
	while true:
		phase = &"spell_pick"
		_ui.show_spells(SPELLS, pm)
		_ui.prompt("Elige un hechizo.")
		var ev: Array = await _next_event()
		if ev[0] == &"back":
			return false
		if ev[0] == &"spell" and pm >= int(SPELLS[ev[1]].cost):
			return await _cast(ev[1])
	return false


## Tocar la canción del hechizo nota por nota.
func _cast(index: int) -> bool:
	var spell: Dictionary = SPELLS[index]
	var song: Array = spell.song
	phase = &"song"
	_ui.show_grid(DuelUI.Rows.BOTH, false, false, true)
	_ui.show_song(song, 0, _settings.show_song_hints)
	_ui.prompt("Toca la canción de %s." % spell.name)
	var times: Array[float] = []
	var i: int = 0
	while i < song.size():
		var ev: Array = await _next_event(NOTE_TIMEOUT if i > 0 else NOTE_TIMEOUT * 2.0)
		if ev[0] == &"timeout":
			return await _fizzle(spell, "Se te fue el ritmo...")
		if ev[0] != &"cell":
			continue
		var cell: int = ev[1]
		Sfx.note(cell)
		_settings.pulse(0.6)
		_ui.mark(&"cell", cell)
		if cell != int(song[i]):
			return await _fizzle(spell, "Nota equivocada...")
		times.append(_now())
		i += 1
		_ui.show_song(song, i, _settings.show_song_hints)
	pm -= int(spell.cost)
	stats.spells += 1
	var in_rhythm: bool = _rhythm_ok(times)
	var mult: float = 1.5 if in_rhythm else 1.0
	phase = &"busy"
	Sfx.play(&"spell")
	_settings.pulse(2.5)
	await _wait(0.25)
	_ui.hide_song()
	if in_rhythm:
		_ui.float_text("¡En ritmo! x1.5", Color(1, 0.85, 0.3), 1)
	var power: int = int(int(spell.power) * mult)
	var vs: float = _tactics.spell_multiplier(spell.name)
	if spell.kind in [&"damage", &"stun"]:
		power = int(power * vs)
		if vs < 1.0:
			_ui.float_text("¡Lo resiste!", Color(0.7, 0.7, 0.8), 2)
		elif vs > 1.0:
			_ui.float_text("¡Su debilidad!", Color(1, 0.85, 0.3), 2)
	_encounter.add_spell(spell.name)
	match spell.kind:
		&"damage":
			_rival.hp -= power
			_rival.hurt(1)
			_ui.flash(Color(1, 0.5, 0.1), 0.4)
			_ui.float_text("Fuego -%d" % power, Color(1, 0.6, 0.2), 0)
			await _hitstop(0.1)
		&"heal":
			hp = mini(hp + power, PLAYER_MAX_HP)
			_ui.flash(Color(0.3, 1, 0.5), 0.3)
			_ui.float_text("+%d PV" % power, Color(0.5, 1, 0.6), 2)
		&"aegis":
			_aegis = true
			_ui.flash(Color(0.4, 0.6, 1), 0.3)
			_ui.float_text("Égida: mitad de daño", Color(0.6, 0.8, 1), 2)
		&"stun":
			_rival.hp -= power
			_rival.hurt(1)
			_rival_stunned = true
			_ui.flash(Color(1, 1, 0.6), 0.5)
			_ui.float_text("Trueno -%d ¡aturdido!" % power, Color(1, 1, 0.6), 0)
			await _hitstop(0.1)
	if _rival.hp <= 0:
		_encounter.finisher = spell.name
	_refresh()
	await _wait(0.7)
	return true


func _fizzle(spell: Dictionary, why: String) -> bool:
	phase = &"busy"
	pm -= int(spell.cost) / 2
	Sfx.play(&"fizzle")
	_settings.pulse(0.8)
	_ui.float_text(why, Color(0.7, 0.7, 0.8), 1)
	_ui.hide_song()
	_refresh()
	await _wait(0.8)
	return true


## Ritmo parejo: el tiempo entre notas casi no cambia (y no es eterno).
func _rhythm_ok(times: Array[float]) -> bool:
	if times.size() < 3:
		return false
	var gaps: Array[float] = []
	for i: int in range(1, times.size()):
		gaps.append(times[i] - times[i - 1])
	var lo: float = gaps.min()
	var hi: float = gaps.max()
	return lo >= 0.15 and hi <= 1.0 and hi - lo <= 0.18


func _use_items() -> bool:
	while true:
		phase = &"items"
		_ui.show_items(_items)
		_ui.prompt("Usar un item gasta tu turno.")
		var ev: Array = await _next_event()
		if ev[0] == &"back":
			return false
		if ev[0] != &"item" or int(_items[ev[1]].count) <= 0:
			continue
		_items[ev[1]].count -= 1
		phase = &"busy"
		Sfx.play(&"spell", 1.3)
		if ev[1] == 0:
			hp = mini(hp + 30, PLAYER_MAX_HP)
			_ui.float_text("+30 PV", Color(0.5, 1, 0.6), 2)
		else:
			pm = mini(pm + 6, PM_MAX)
			_ui.float_text("+6 PM", Color(0.5, 0.7, 1), 2)
		_refresh()
		await _wait(0.6)
		return true
	return false


func _flee() -> bool:
	phase = &"busy"
	_ui.prompt("Intentas huir...")
	await _wait(0.5)
	if rng.randf() < FLEE_CHANCE:
		result = &"fled"
		Sfx.play(&"swing", 0.7)
		return true
	Sfx.play(&"fizzle")
	_ui.float_text("¡No pudiste huir!", Color(1, 0.6, 0.5), 1)
	await _wait(0.6)
	return true


# --- Turno del rival --------------------------------------------------------

func _rival_turn() -> void:
	_encounter.turns += 1
	var strikes: int = 1 + _tactics.extra_strikes
	if _rival.hp < _rival.max_hp * 0.66:
		strikes += 1
	if _rival.hp < _rival.max_hp * 0.33:
		strikes += 1
	phase = &"rival"
	_ui.show_grid(DuelUI.Rows.TOP, false, false)
	_ui.prompt("¡Turno del cubo! Bloquea del lado de la flecha cuando el aro llegue al círculo.")
	await _wait(0.6)
	for n: int in strikes:
		await _rival_strike()
		if hp <= 0:
			break
		await _wait(0.4)
	_aegis = false
	telegraph_side = -1


func _rival_strike() -> void:
	var side: int = rng.randi_range(0, 2)
	var windup: float = _tactics.pick_windup(rng)
	telegraph_side = side
	impact_at = _now() + windup
	phase = &"block"
	_ui.telegraph(side, windup, PERFECT_WINDOW)
	_rival.telegraph(side, windup)
	Sfx.play(&"windup")
	var pressed_side: int = -1
	var pressed_at: float = 0.0
	# Esperar toques hasta el impacto. Solo cuenta el PRIMER toque
	# (si no, bastaría con machacar el botón).
	while true:
		var remaining: float = impact_at - _now()
		if remaining <= 0.0:
			break
		var ev: Array = await _next_event(remaining)
		if ev[0] == &"cell" and ev[1] < 3 and pressed_side == -1:
			pressed_side = ev[1]
			pressed_at = _now()
			_ui.mark(&"cell", pressed_side)
			Sfx.play(&"tick")
	phase = &"busy"
	_ui.clear_telegraph()
	_rival.strike()
	var damage: int = RIVAL_DAMAGE
	if _aegis:
		damage = damage / 2
	if pressed_side == side and impact_at - pressed_at <= PERFECT_WINDOW:
		stats.perfect += 1
		pa = mini(pa + PERFECT_REFUND, PA_MAX)
		Sfx.play(&"perfect")
		_settings.pulse(3.5)
		_ui.flash(Color(1, 0.85, 0.3), 0.3)
		_ui.float_text("¡PERFECTO! +%d PA" % PERFECT_REFUND, Color(1, 0.85, 0.3), side)
		_refresh()
		await _hitstop(0.12)
		return
	if pressed_side == side:
		stats.blocked += 1
		damage = ceili(damage * 0.35)
		Sfx.play(&"block")
		_settings.pulse(1.5)
		_ui.float_text("Bloqueo -%d" % damage, Color(0.6, 0.8, 1.0), side)
		await _hitstop(0.05)
	else:
		stats.hit += 1
		Sfx.play(&"hurt")
		_settings.pulse(3.0)
		_player.shake(0.08, 0.22)
		_ui.flash(Color(0.9, 0.1, 0.1), 0.45)
		var why: String = "" if pressed_side == -1 else " (era %s)" % SIDE_WORD[side]
		_ui.float_text("-%d%s" % [damage, why], Color(1, 0.4, 0.4), side)
		await _hitstop(0.08)
	hp = maxi(hp - damage, 0)
	_refresh()


# --- Utilidades ---------------------------------------------------------------

## Entrega lo que pasó a la memoria de ESTE rival y a tu piedra. Es el único
## lugar donde un duelo cambia algo fuera de sí mismo.
func _save_encounter() -> void:
	_encounter.result = result
	_encounter.perfect_blocks = int(stats.perfect)
	_encounter.blocks = int(stats.blocked)
	_encounter.hits_taken = int(stats.hit)
	_memory.record(_encounter)
	if Piedra.record.record(_encounter):
		_ui.prompt("Absorbes un fragmento de su piedra. Tu piedra: nivel %d." % Piedra.record.level())
	Piedra.save()
	memory_saved.emit(_memory)


func _refresh() -> void:
	_ui.set_rival(_rival.display_name, maxi(_rival.hp, 0), _rival.max_hp)
	_ui.set_stats(hp, PLAYER_MAX_HP, pa, PA_MAX, pm, PM_MAX)


## Espera el siguiente toque en la UI, o &"timeout" si pasa `timeout`.
## Devuelve [kind, value]. El _token invalida timers viejos.
func _next_event(timeout: float = -1.0) -> Array:
	_token += 1
	var my: int = _token
	if timeout > 0.0:
		get_tree().create_timer(timeout, false).timeout.connect(func() -> void:
			if my == _token:
				_ui.event.emit(&"timeout", -1))
	var ev: Array = await _ui.event
	_token += 1
	return ev


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


## "Hitstop": congelar el juego unos milisegundos al pegar. Es lo que hace
## que un golpe se SIENTA pesado (lo usan casi todos los juegos de pelea).
func _hitstop(seconds: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(seconds, false, false, true).timeout
	Engine.time_scale = 1.0


func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0
