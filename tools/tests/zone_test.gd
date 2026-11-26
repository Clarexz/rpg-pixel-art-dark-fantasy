extends Node
## Prueba automática de mundo y zonas (fase 5, v0.6.1):
## 1) World carga su zona inicial y te pone en su PlayerStart,
## 2) conecta a los enemigos de ESA zona, 3) el duelo sabe en qué zona estás,
## 4) cambiar de zona quita la anterior (y sus enemigos) y monta la nueva,
## 5) (v0.6.2) con mapa de navegación, un enemigo rodea una pared para
##    alcanzarte, y ese duelo se registra con el id de esa zona,
## 6) no se puede cambiar de zona a media pelea,
## 7) (v0.6.2) el kit de bloques existe y el nivel gris tiene su ruina y navegación,
## 8) (v0.6.3) sin zona elegida, el juego empieza en la Hondonada de ceniza,
##    con sus 6 enemigos comunes y el Lobo; desde el inicio se puede llegar
##    caminando a cada enemigo y a la meseta del altar,
## 9) (v0.6.3) Ajustes lleva al campo de pruebas y de regreso.
## Corre en CI con: godot --headless --path . res://tools/tests/zone_test.tscn

const WORLD: PackedScene = preload("res://world/world.tscn")
const TEST_ZONE: PackedScene = preload("res://tools/tests/fixtures/test_zone.tscn")
const NAV_ZONE: PackedScene = preload("res://tools/tests/fixtures/nav_zone.tscn")
const KIT: MeshLibrary = preload("res://assets/tiles/tile_kit.tres")

var _failures: PackedStringArray = []
var _world: World


func _ready() -> void:
	RivalRegistry.save_enabled = false
	Piedra.save_enabled = false
	Inventory.save_enabled = false
	Piedra.use_record(PlayerRecord.new())
	_world = WORLD.instantiate() as World
	# Estas pruebas usan el campo de pruebas (nivel gris).
	_world.start_zone = load(World.PRACTICE_ZONE)
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

	print("Paso 5: el enemigo rodea la pared (navegación)")
	var scav: Enemy = new_zone.enemies()[0]
	_check(scav.engaged.get_connections().size() == 1, "el enemigo de la zona nueva no está conectado")
	var nav_zone: Zone = _world.load_zone(NAV_ZONE)
	if not nav_zone.navigation_baked:
		await nav_zone.navigation_ready
	var region: NavigationRegion3D = nav_zone.get_node("Navigation")
	_check(region.navigation_mesh.get_polygon_count() > 0, "no se calculó el mapa de navegación")
	var hunter: Enemy = nav_zone.enemies()[0]
	var caught: Array[StringName] = []
	hunter.engaged.connect(func(_e: Enemy, adv: StringName) -> void: caught.append(adv))
	var t0: int = Time.get_ticks_msec()
	while caught.is_empty() and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().physics_frame
	_check(not caught.is_empty(), "el enemigo no logró rodear la pared en 15 s (quedó en %s)" % hunter.global_position)
	await _frames(5)
	_check(duel.is_active(), "al alcanzarte no empezó el duelo")
	_check(duel._encounter != null and duel._encounter.zone == &"nav_zone", "el duelo no se registró en nav_zone")

	print("Paso 6: no se cambia de zona a media pelea")
	var same: Zone = _world.load_zone(TEST_ZONE)
	_check(same == nav_zone and is_instance_valid(nav_zone), "cambió de zona durante un duelo")

	print("Paso 7: kit de bloques y nivel gris")
	var names: PackedStringArray = []
	for id: int in KIT.get_item_list():
		names.append(KIT.get_item_name(id))
		_check(KIT.get_item_mesh(id) != null, "el bloque %d no tiene malla" % id)
		_check(not KIT.get_item_shapes(id).is_empty(), "el bloque %d no tiene colisión" % id)
	for needed: String in ["suelo_ceniza", "camino", "pared_roca", "pared_ladrillo", "rampa_baja", "caja"]:
		_check(needed in names, "falta el bloque %s en el kit" % needed)
	var grey: Zone = load("res://world/zones/greybox/greybox.tscn").instantiate()
	_check(grey.get_node_or_null("Level/Ruina") is GridMap, "el nivel gris no tiene la ruina de bloques")
	_check(grey.get_node_or_null("Navigation") is NavigationRegion3D, "el nivel gris no tiene navegación")
	if grey.get_node_or_null("Level/Ruina") is GridMap:
		_check((grey.get_node("Level/Ruina") as GridMap).get_used_cells().size() > 10, "la ruina está vacía")
	grey.free()

	await _test_hondonada()


func _test_hondonada() -> void:
	print("Paso 8: la Hondonada de ceniza")
	_world.queue_free()
	await _frames(2)
	var world: World = WORLD.instantiate() as World
	add_child(world)
	_world = world
	_check(world.zone != null and world.zone.zone_id() == &"hondonada", "el juego no empezó en la Hondonada")
	if world.zone == null:
		return
	var t0: int = Time.get_ticks_msec()
	if not world.zone.navigation_baked:
		await world.zone.navigation_ready
	print("  mapa de navegación calculado en %d ms" % (Time.get_ticks_msec() - t0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player: Player = world.get_node("Player")
	var start: Vector3 = (world.zone.get_node("PlayerStart") as Node3D).global_position
	_check(player.global_position.distance_to(start) < 0.5, "no empezaste en el campamento")
	var counts: Dictionary = {}
	for e: Enemy in world.zone.enemies():
		counts[e.data.id] = int(counts.get(e.data.id, 0)) + 1
	_check(int(counts.get(&"scavenger", 0)) == 4, "debería haber 4 Carroñeros (%s)" % counts)
	_check(int(counts.get(&"slag_golem", 0)) == 2, "debería haber 2 Gólems (%s)" % counts)
	_check(int(counts.get(&"ash_wolf", 0)) == 1, "debería estar el Lobo de ceniza (%s)" % counts)
	var map: RID = world.get_world_3d().navigation_map
	var from: Vector3 = NavigationServer3D.map_get_closest_point(map, start)
	for e: Enemy in world.zone.enemies():
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, from, e.global_position, true)
		var end_ok: bool = not path.is_empty() and _flat(path[path.size() - 1]).distance_to(_flat(e.global_position)) < 1.5
		_check(end_ok, "no hay camino caminando hasta %s en %s" % [e.name, e.global_position])
	# Meseta del altar: centro del lugar del altar, a 1 m de alto.
	var altar: Vector3 = Vector3(1, 1, -39)
	var to_altar: PackedVector3Array = NavigationServer3D.map_get_path(map, from, altar, true)
	_check(not to_altar.is_empty() and to_altar[to_altar.size() - 1].y > 0.6
			and _flat(to_altar[to_altar.size() - 1]).distance_to(_flat(altar)) < 3.0,
			"no se puede subir a la meseta del altar")
	var length: float = 0.0
	for i: int in range(1, to_altar.size()):
		length += to_altar[i - 1].distance_to(to_altar[i])
	print("  del campamento al altar: %.0f m (≈%.0f s caminando)" % [length, length / player.walk_speed])

	print("Paso 9: Ajustes lleva al campo de pruebas y de regreso")
	var panel: ControlSettingsPanel = world.get_node("HUD/SettingsPanel")
	world._open_settings()
	await _frames(2)
	var button: Button = panel.find_child("ZoneSwitchButton", true, false) as Button
	_check(button != null and "pruebas" in button.text, "no está el botón para ir al campo de pruebas")
	if button:
		button.pressed.emit()
	await _frames(3)
	_check(world.zone.zone_id() == &"greybox", "no se cambió al campo de pruebas")
	_check(not get_tree().paused, "el juego quedó en pausa al cambiar de zona")
	world._open_settings()
	await _frames(2)
	button = panel.find_child("ZoneSwitchButton", true, false) as Button
	_check(button != null and "Hondonada" in button.text, "no está el botón para volver a la Hondonada")
	if button:
		button.pressed.emit()
	await _frames(3)
	_check(world.zone.zone_id() == &"hondonada", "no se volvió a la Hondonada")


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)
