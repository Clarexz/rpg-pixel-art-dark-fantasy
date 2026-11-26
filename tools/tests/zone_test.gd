extends Node
## Prueba automática de mundo y zonas (fase 5, v0.6.1):
## 1) World carga su zona inicial y te pone en su PlayerStart,
## 2) conecta a los enemigos de ESA zona, 3) el duelo sabe en qué zona estás,
## 4) cambiar de zona quita la anterior (y sus enemigos) y monta la nueva,
## 5) un duelo en la zona nueva se registra con el id de esa zona,
## 6) no se puede cambiar de zona a media pelea.
## Corre en CI con: godot --headless --path . res://tools/tests/zone_test.tscn

const WORLD: PackedScene = preload("res://world/world.tscn")
const TEST_ZONE: PackedScene = preload("res://tools/tests/fixtures/test_zone.tscn")

var _failures: PackedStringArray = []
var _world: World


func _ready() -> void:
	RivalRegistry.save_enabled = false
	Piedra.save_enabled = false
	Inventory.save_enabled = false
	Piedra.use_record(PlayerRecord.new())
	_world = WORLD.instantiate() as World
	add_child(_world)
	await _frames(5)
	(_world.get_node("Player") as Player).settings.haptics_enabled = false
	await _run()
	if _failures.is_empty():
		print("ZONE TEST OK")
		get_tree().quit(0)
	else:
		for f: String in _failures:
			printerr("ZONE TEST FAIL: ", f)
		get_tree().quit(1)


func _run() -> void:
	var player: Player = _world.get_node("Player")
	var duel: Duel = _world.get_node("Duel")

	print("Paso 1: zona inicial")
	_check(_world.zone != null, "World no cargó ninguna zona")
	_check(_world.zone.get_parent() == _world.get_node("ZoneSlot"), "la zona no quedó dentro de ZoneSlot")
	_check(_world.zone.zone_id() == &"greybox", "la zona inicial debería ser greybox, es %s" % _world.zone.zone_id())
	var start: Vector3 = (_world.zone.get_node("PlayerStart") as Node3D).global_position
	_check(player.global_position.distance_to(start) < 0.5, "el jugador no empezó en PlayerStart (%s vs %s)" % [player.global_position, start])

	print("Paso 2: enemigos conectados")
	var old_enemies: Array[Enemy] = _world.zone.enemies()
	_check(old_enemies.size() == 3, "el nivel gris debería tener 3 enemigos, tiene %d" % old_enemies.size())
	for e: Enemy in old_enemies:
		_check(e.engaged.get_connections().size() == 1, "%s no está conectado a World" % e.name)

	print("Paso 3: el duelo sabe la zona")
	_check(duel.zone_id == &"greybox", "Duel.zone_id = %s" % duel.zone_id)

	print("Paso 4: cambiar de zona")
	var old_zone: Zone = _world.zone
	var new_zone: Zone = _world.load_zone(TEST_ZONE)
	await _frames(3)
	_check(not is_instance_valid(old_zone), "la zona anterior no se liberó")
	for e: Enemy in old_enemies:
		_check(not is_instance_valid(e), "un enemigo de la zona anterior sigue vivo")
	_check(_world.zone == new_zone and new_zone.zone_id() == &"test_zone", "no quedó cargada la zona nueva")
	_check(_world.get_node("ZoneSlot").get_child_count() == 1, "hay más de una zona en la ranura")
	_check(player.global_position.distance_to(Vector3(5, 0, 5)) < 0.6, "el jugador no apareció en el inicio de la zona nueva (%s)" % player.global_position)
	_check(get_tree().get_nodes_in_group("enemy").size() == 1, "quedaron enemigos de más en el árbol")
	_check(duel.zone_id == &"test_zone", "Duel.zone_id no cambió (%s)" % duel.zone_id)

	print("Paso 5: duelo en la zona nueva")
	var scav: Enemy = new_zone.enemies()[0]
	_check(scav.engaged.get_connections().size() == 1, "el enemigo de la zona nueva no está conectado")
	scav.take_hit(Vector3.ZERO)
	await _frames(5)
	_check(duel.is_active(), "golpear al enemigo de la zona nueva no empezó el duelo")
	_check(duel._encounter != null and duel._encounter.zone == &"test_zone", "el duelo no se registró en test_zone")

	print("Paso 6: no se cambia de zona a media pelea")
	var same: Zone = _world.load_zone(TEST_ZONE)
	_check(same == new_zone and is_instance_valid(new_zone), "cambió de zona durante un duelo")


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)
