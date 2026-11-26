class_name Duel
extends CanvasLayer
## Reglas del duelo por turnos (estilo Expedition 33, pero a una mano).
##
## Tu turno: menú Cuerpo a cuerpo / Hechizos / Items / Huir.
## - Cuerpo a cuerpo: fila de abajo = atacar izq/centro/der. Cada golpe
##   cuesta PA; puedes encadenar golpes mientras te alcance. El enemigo cubre
##   un lado (al azar... y un rival, cuando te conoce: ver rivals/rival_tactics.gd).
## - Hechizos: eliges uno y tocas su "canción" (3-4 casillas) en la misma
##   cuadrícula. Cuesta PM. Si la tocas con ritmo parejo, sale más fuerte.
## - Items: los de tu inventario (items/inventory.gd). Gasta el turno.
## - Huir: más fácil entre más débil es el enemigo según tu piedra.
## Turno del enemigo: usa el siguiente movimiento de su patrón
## (combat/enemy_ai.gd): golpe simple, combo, finta o cargado. Cada golpe
## avisa de qué lado viene; bloquea con la fila de arriba del mismo lado. Si
## bloqueas justo antes del golpe (bloqueo perfecto) no te hace daño y
## recuperas PA.
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
## Daño del golpe extra de un rival que "ataca más seguido".
const EXTRA_STRIKE_DAMAGE: int = 10
## Fracción del daño que recibes con un bloqueo normal (no perfecto).
const BLOCK_DAMAGE_MULT: float = 0.35
## Segundos antes del impacto en los que bloquear cuenta como perfecto.
const PERFECT_WINDOW: float = 0.25
## Probabilidad de huir según lo que lee tu piedra del enemigo.
const FLEE_CHANCE: Dictionary = {&"weaker": 0.85, &"similar": 0.65, &"stronger": 0.4, &"broken": 0.25}
const FLEE_WORD: Dictionary = {&"weaker": "fácil", &"similar": "parejo", &"stronger": "difícil", &"broken": "muy difícil"}
## En qué punto del aviso cambia de lado la finta (0.5 = a la mitad).
const FEINT_SWITCH_AT: float = 0.5
## Pausa entre golpes de un combo (más corta que entre golpes normales).
const COMBO_GAP: float = 0.15
## Cuánto baja la vista en el duelo para ver al enemigo completo.
const DUEL_PITCH_DEG: float = -12.0
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
## true mientras el aviso actual es una finta que todavía no cambia de lado.
var telegraph_is_feint: bool = false
## Momento del impacto del ataque actual del enemigo (segundos, ver _now()).
var impact_at: float = 0.0
var result: StringName = &""
var stats: Dictionary = {}
## Movimiento que el enemigo usó (o está cargando) en su último turno.
var last_move: EnemyMove
## true si el enemigo está cargando un golpe fuerte para su próximo turno.
var charging: bool = false
## Items que ganaste al vencer (nombres), para mostrar y para las pruebas.
var loot_won: PackedStringArray = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _player: Player
var _enemy: Enemy
var _settings: ControlSettings
## Memoria del rival (null si es un enemigo común: esos no recuerdan).
var _memory: RivalMemory
var _inventory: Inventory
## Cómo pelea en ESTE duelo (un rival lo saca de su memoria al empezar).
var _tactics: RivalTactics
## Lo que va pasando en este duelo; al final se entrega a la memoria.
var _encounter: Encounter
var _transition: PixelateTransition
var _reading: PowerReading
var _step: int = 0
var _aegis: bool = false
var _enemy_stunned: bool = false
var _token: int = 0

@onready var _ui: DuelUI = $SafeArea/DuelUI


func _ready() -> void:
	layer = 10
	rng.randomize()


func is_active() -> bool:
	return phase != &"idle"


## memory = la memoria de ESE rival, o null si es un enemigo común.
func start(player: Player, enemy: Enemy, advantage: StringName, settings: ControlSettings,
		memory: RivalMemory, inventory: Inventory, transition: PixelateTransition) -> void:
	_player = player
	_enemy = enemy
	_settings = settings
	_memory = memory if enemy.is_rival() else null
	_inventory = inventory
	_transition = transition
	if _memory != null:
		_tactics = RivalTactics.plan(enemy.data as RivalData, _memory)
	else:
		_tactics = RivalTactics.for_enemy(enemy.data)
	_reading = Piedra.scan(enemy.data, _memory)
	_encounter = Encounter.new()
	_encounter.rival_id = enemy.data.id
	_encounter.is_rival = _memory != null
	_encounter.advantage = advantage
	hp = PLAYER_MAX_HP
	pa = PA_START
	pm = PM_START
	result = &""
	_aegis = false
	_enemy_stunned = false
	charging = false
	last_move = null
	loot_won = []
	_step = 0
	stats = {"perfect": 0, "blocked": 0, "hit": 0, "attacks": 0, "spells": 0, "feints_bitten": 0}
	_run(advantage)


## Probabilidad de huir de este enemigo (según la lectura de tu piedra).
func flee_chance() -> float:
	return float(FLEE_CHANCE.get(_reading.tier, 0.65))


# --- Flujo principal -------------------------------------------------------

func _run(advantage: StringName) -> void:
	phase = &"intro"
	await _intro(advantage)
	if advantage == &"rival":
		await _enemy_turn()
	while not _is_over():
		await _player_turn()
		if _is_over():
			break
		if _enemy_stunned:
			_enemy_stunned = false
			_ui.prompt("%s está aturdido y pierde su turno." % _enemy.display_name)
			await _wait(0.9)
			continue
		await _enemy_turn()
	await _outro()


func _is_over() -> bool:
	if result == &"fled":
		return true
	if _enemy.hp <= 0:
		result = &"win"
	elif hp <= 0:
		result = &"lose"
	return result != &""


func _intro(advantage: StringName) -> void:
	_player.controls_enabled = false
	_player.attack_held = false
	Sfx.play(&"engage")
	_settings.pulse(3.0)
	await _transition.cover(0.3)

	# Acomodar la escena "en el lugar": el enemigo queda enfrente de ti.
	var to_enemy: Vector3 = _enemy.global_position - _player.global_position
	to_enemy.y = 0.0
	var dir: Vector3 = to_enemy.normalized() if to_enemy.length() > 0.1 else -_player.global_basis.z
	_player.face_direction(dir)
	var spot: Vector3 = _player.global_position + dir * _enemy.data.duel_distance
	spot.y = _player.global_position.y
	_enemy.enter_duel(spot, _player.global_position)
	_enemy.view_right = _player.global_basis.x
	_player.duel_pitch = deg_to_rad(DUEL_PITCH_DEG)
	_player.lower_weapon(true)

	_ui.left_handed = _settings.left_handed
	_ui.apply_hand()
	_ui.banner("")
	_ui.status("")
	_ui.hide_song()
	_ui.clear_telegraph()
	# Saludo (un rival: según lo que recuerda) + lectura de tu piedra.
	var line: String
	if _memory != null:
		var fame: String = Piedra.record.fame_title(_encounter.zone)
		line = "%s: \"%s\"" % [_enemy.display_name,
				RivalDialogue.greeting(_enemy.data as RivalData, _memory, _tactics, fame)]
	else:
		line = _enemy.data.line_first_meet if not _enemy.data.line_first_meet.is_empty() \
				else "¡%s te cierra el paso!" % _enemy.display_name
	_ui.say("%s\n◆ Piedra: %s." % [line, _reading.text])
	if advantage == &"player":
		_enemy.hp = maxi(_enemy.hp - FIRST_STRIKE_DAMAGE, 1)
		pa += 2
		_ui.prompt("¡Golpeaste primero! Empiezas tú con +2 PA.")
	else:
		_ui.prompt("¡Te alcanzó! Ataca primero.")
	_refresh()
	_ui.show_menu(FLEE_WORD.get(_reading.tier, ""))
	_ui.set_rows(DuelUI.Rows.NONE)
	_ui.show()
	await _transition.reveal(0.3)
	if advantage == &"player":
		_enemy.hurt(1)
		_ui.float_text("-%d" % FIRST_STRIKE_DAMAGE, Color.WHITE, 1)
		Sfx.play(&"hit")
	await _wait(0.7)


func _outro() -> void:
	phase = &"outro"
	charging = false
	_ui.clear_telegraph()
	_ui.hide_song()
	_ui.status("")
	_ui.show_grid(DuelUI.Rows.NONE, false, false)
	match result:
		&"win":
			_enemy.die()
			Sfx.play(&"perfect", 0.7)
			_ui.banner("¡VICTORIA!")
			var said: String = RivalDialogue.defeated(_enemy.data)
			_ui.say("%s: \"%s\"" % [_enemy.display_name, said] if _memory != null else said)
			loot_won = _inventory.roll_loot(_enemy.data.loot, rng)
		&"lose":
			Sfx.play(&"hurt", 0.6)
			_ui.banner("Caíste...")
			_ui.say("%s: \"Vuelve cuando seas más fuerte.\"" % _enemy.display_name if _memory != null
					else "%s te deja tirado y se va." % _enemy.display_name)
		&"fled":
			_ui.banner("Huiste")
			_ui.say("%s: \"¡Eso, corre!\"" % _enemy.display_name if _memory != null
					else "Te escapas. %s te pierde de vista." % _enemy.display_name)
	_inventory.save()
	var notes: PackedStringArray = []
	if not loot_won.is_empty():
		notes.append("Botín: %s." % ", ".join(loot_won))
	var absorbed: bool = _save_encounter()
	if absorbed:
		notes.append("Absorbes un fragmento de su piedra. Tu piedra: nivel %d." % Piedra.record.level())
	_ui.prompt(" ".join(notes))
	await _wait(1.4 if notes.is_empty() else 2.2)
	await _transition.cover(0.3)
	_ui.hide()
	_ui.banner("")
	_enemy.leave_duel(result)
	_player.duel_pitch = 0.0
	_player.lower_weapon(false)
	match result:
		&"lose":
			_player.respawn()
		&"fled":
			# Te alejas unos pasos del enemigo.
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
		_ui.show_menu(FLEE_WORD.get(_reading.tier, ""))
		_ui.prompt("Tu turno. Elige qué hacer." if not charging
				else "¡Está cargando un golpe fuerte! Córtalo con Trueno o prepárate con Égida.")
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
					if _enemy.hp <= 0:
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
		_enemy.hp -= GUARDED_DAMAGE
		_enemy.show_guard(side)
		Sfx.play(&"block")
		_settings.pulse(1.0)
		_ui.float_text("¡Lo bloqueó! -%d" % GUARDED_DAMAGE, Color(0.6, 0.8, 1.0), side)
		await _hitstop(0.04)
	else:
		_enemy.hp -= HIT_DAMAGE
		_enemy.hurt(side)
		Sfx.play(&"hit")
		_settings.pulse(2.2)
		_player.shake(0.03, 0.1)
		_ui.float_text("-%d" % HIT_DAMAGE, Color.WHITE, side)
		await _hitstop(0.07)
	_refresh()
	await _wait(0.18)


## Qué lado cubre el enemigo. Al principio adivina; un rival que ya te
## conoce (memoria) cubre tu lado favorito la mayoría de las veces.
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
			_enemy.hp -= power
			_enemy.hurt(1)
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
			_enemy.hp -= power
			_enemy.hurt(1)
			_enemy_stunned = true
			_ui.flash(Color(1, 1, 0.6), 0.5)
			_ui.float_text("Trueno -%d ¡aturdido!" % power, Color(1, 1, 0.6), 0)
			if charging:
				_cancel_charge()
			await _hitstop(0.1)
	if _enemy.hp <= 0:
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
		var entries: Array[Dictionary] = _inventory.entries()
		_ui.show_items(entries)
		_ui.prompt("Usar un item gasta tu turno.")
		var ev: Array = await _next_event()
		if ev[0] == &"back":
			return false
		if ev[0] != &"item":
			continue
		var id: StringName = entries[ev[1]].id
		if not _inventory.take(id):
			continue
		await _apply_item(id)
		return true
	return false


func _apply_item(id: StringName) -> void:
	var def: Dictionary = Inventory.CATALOG[id]
	var power: int = int(def.power)
	phase = &"busy"
	match def.kind:
		&"heal":
			Sfx.play(&"spell", 1.3)
			hp = mini(hp + power, PLAYER_MAX_HP)
			_ui.float_text("+%d PV" % power, Color(0.5, 1, 0.6), 2)
		&"mana":
			Sfx.play(&"spell", 1.3)
			pm = mini(pm + power, PM_MAX)
			_ui.float_text("+%d PM" % power, Color(0.5, 0.7, 1), 2)
		&"bomb":
			# Daño fijo: no lo bloquea ni lo resiste.
			Sfx.play(&"hit", 0.6)
			_settings.pulse(2.5)
			_enemy.hp -= power
			_enemy.hurt(1)
			_ui.flash(Color(0.9, 0.6, 0.4), 0.4)
			_ui.float_text("¡Bum! -%d" % power, Color(1, 0.7, 0.4), 1)
			await _hitstop(0.08)
	_refresh()
	await _wait(0.6)


func _flee() -> bool:
	phase = &"busy"
	_ui.prompt("Intentas huir...")
	await _wait(0.5)
	if rng.randf() < flee_chance():
		result = &"fled"
		Sfx.play(&"swing", 0.7)
		return true
	Sfx.play(&"fizzle")
	_ui.float_text("¡No pudiste huir!", Color(1, 0.6, 0.5), 1)
	await _wait(0.6)
	return true


# --- Turno del enemigo ----------------------------------------------------------

func _enemy_turn() -> void:
	_encounter.turns += 1
	phase = &"rival"
	_ui.show_grid(DuelUI.Rows.TOP, false, false)
	var move: EnemyMove
	if charging:
		# Suelta el golpe que cargó el turno pasado.
		move = last_move
		charging = false
		_ui.status("")
		_ui.prompt("¡%s suelta %s! Bloquea." % [_enemy.display_name, move.display_name])
	else:
		move = EnemyAI.choose(_enemy.data, _step, float(_enemy.hp) / _enemy.max_hp)
		_step += 1
		last_move = move
		if move.kind == EnemyMove.Kind.CHARGED:
			await _start_charge(move)
			await _extra_strikes()
			return
		match move.kind:
			EnemyMove.Kind.COMBO:
				_ui.prompt("¡%s: combo de %d golpes!" % [move.display_name, move.hits])
			EnemyMove.Kind.FEINT:
				_ui.prompt("%s... ¡ojo, puede ser una finta!" % move.display_name)
			_:
				_ui.prompt("¡Turno de %s! Bloquea del lado de la flecha cuando el aro llegue al círculo." % _enemy.display_name)
	await _wait(0.6)
	match move.kind:
		EnemyMove.Kind.COMBO:
			var sides: Array[int] = EnemyAI.combo_sides(move.hits, rng)
			_ui.preview(sides)
			await _wait(0.8)
			for i: int in sides.size():
				await _strike(move, sides[i], false, move.damage)
				if hp <= 0:
					break
				await _wait(COMBO_GAP)
		EnemyMove.Kind.FEINT:
			await _strike(move, rng.randi_range(0, 2), true, move.damage)
		_:
			await _strike(move, rng.randi_range(0, 2), false, move.damage)
	if hp > 0:
		await _extra_strikes()
	_aegis = false
	telegraph_side = -1


## Un rival que aprendió a "atacar más seguido" agrega un golpe al final.
func _extra_strikes() -> void:
	for n: int in _tactics.extra_strikes:
		if hp <= 0:
			return
		await _wait(0.4)
		var quick: EnemyMove = EnemyMove.make(&"extra", "Golpe extra", EnemyMove.Kind.SIMPLE, EXTRA_STRIKE_DAMAGE)
		await _strike(quick, rng.randi_range(0, 2), false, EXTRA_STRIKE_DAMAGE)
	telegraph_side = -1


func _start_charge(move: EnemyMove) -> void:
	charging = true
	phase = &"busy"
	_enemy.charge_up()
	Sfx.play(&"windup", 0.6)
	_settings.pulse(2.0)
	_ui.status("⚡ Cargando %s" % move.display_name)
	_ui.flash(Color(1, 0.85, 0.3), 0.25)
	_ui.prompt("¡%s está cargando %s! El próximo turno pega fuerte: córtalo con Trueno o usa Égida." % [_enemy.display_name, move.display_name])
	await _wait(1.6)


func _cancel_charge() -> void:
	charging = false
	_enemy.cancel_charge()
	_ui.status("")
	_ui.float_text("¡Carga cortada!", Color(1, 1, 0.6), 2)


## Un golpe del enemigo: aviso (o finta), esperar tu bloqueo, resolver.
func _strike(move: EnemyMove, side: int, feint: bool, base_damage: int) -> void:
	var windup: float = _tactics.pick_windup_for(move.windup, rng)
	impact_at = _now() + windup
	phase = &"block"
	var shown: int = EnemyAI.feint_side(side, rng) if feint else side
	telegraph_side = shown
	telegraph_is_feint = feint
	_ui.telegraph(shown, windup, PERFECT_WINDOW, feint)
	_enemy.telegraph(shown, windup)
	Sfx.play(&"windup")
	var switch_at: float = impact_at - windup * (1.0 - FEINT_SWITCH_AT) if feint else INF
	var pressed_side: int = -1
	var pressed_at: float = 0.0
	# Esperar toques hasta el impacto. Solo cuenta el PRIMER toque
	# (si no, bastaría con machacar el botón).
	while true:
		var now: float = _now()
		if telegraph_is_feint and now >= switch_at:
			telegraph_is_feint = false
			telegraph_side = side
			_ui.retarget(side)
			_enemy.feint_switch(side, impact_at - now)
			Sfx.play(&"swing", 1.4)
		var remaining: float = impact_at - _now()
		if remaining <= 0.0:
			break
		var wait_for: float = remaining
		if telegraph_is_feint:
			wait_for = minf(remaining, maxf(switch_at - _now(), 0.01))
		var ev: Array = await _next_event(wait_for)
		if ev[0] == &"cell" and ev[1] < 3 and pressed_side == -1:
			pressed_side = ev[1]
			pressed_at = _now()
			_ui.mark(&"cell", pressed_side)
			Sfx.play(&"tick")
	phase = &"busy"
	telegraph_is_feint = false
	_ui.clear_telegraph()
	_enemy.strike()
	var damage: int = base_damage
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
		damage = ceili(damage * BLOCK_DAMAGE_MULT)
		Sfx.play(&"block")
		_settings.pulse(1.5)
		_ui.float_text("Bloqueo -%d" % damage, Color(0.6, 0.8, 1.0), side)
		await _hitstop(0.05)
	else:
		stats.hit += 1
		if feint and pressed_side != -1 and pressed_at < switch_at:
			stats.feints_bitten += 1
		Sfx.play(&"hurt")
		_settings.pulse(3.0)
		_player.shake(0.08 if damage < 20 else 0.14, 0.22)
		_ui.flash(Color(0.9, 0.1, 0.1), 0.45)
		var why: String = ""
		if feint and pressed_side != -1 and pressed_at < switch_at:
			why = " ¡Era una finta!"
		elif pressed_side != -1:
			why = " (era %s)" % SIDE_WORD[side]
		_ui.float_text("-%d%s" % [damage, why], Color(1, 0.4, 0.4), side)
		await _hitstop(0.08)
	hp = maxi(hp - damage, 0)
	_refresh()


# --- Utilidades ---------------------------------------------------------------

## Entrega lo que pasó a la memoria de ESTE rival (si es rival) y a tu piedra.
## Es el único lugar donde un duelo cambia algo fuera de sí mismo.
## Devuelve true si absorbiste un fragmento de piedra nuevo.
func _save_encounter() -> bool:
	_encounter.result = result
	_encounter.perfect_blocks = int(stats.perfect)
	_encounter.blocks = int(stats.blocked)
	_encounter.hits_taken = int(stats.hit)
	if _memory != null:
		_memory.record(_encounter)
	var absorbed: bool = Piedra.record.record(_encounter)
	Piedra.save()
	if _memory != null:
		memory_saved.emit(_memory)
	return absorbed


func _refresh() -> void:
	_ui.set_rival(_enemy.display_name, maxi(_enemy.hp, 0), _enemy.max_hp)
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
