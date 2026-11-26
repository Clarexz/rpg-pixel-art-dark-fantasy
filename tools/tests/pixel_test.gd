extends Node
## Prueba automática del pipeline pixel art (v0.3.0):
## 1) el mundo 3D se dibuja en el SubViewport chiquito con factor entero,
## 2) la cámara espejo sigue a la del jugador (también al moverse),
## 3) "Nativa" regresa al render normal, 4) el override de renderer,
## 5) la prueba de rendimiento corre (modo rápido) y produce un reporte.
## Corre en CI con: godot --headless --path . res://tools/tests/pixel_test.tscn

const GREYBOX: PackedScene = preload("res://world/greybox/greybox.tscn")
const BENCH: PackedScene = preload("res://world/benchmark/benchmark.tscn")

var _failures: PackedStringArray = []


func _ready() -> void:
	RivalMemory.save_enabled = false
	await _run()
	if _failures.is_empty():
		print("PIXEL TEST OK")
		get_tree().quit(0)
	else:
		for f: String in _failures:
			printerr("PIXEL TEST FAIL: ", f)
		get_tree().quit(1)


func _run() -> void:
	var root: Window = get_tree().root
	var world: Node3D = GREYBOX.instantiate()
	add_child(world)
	var player: Player = world.get_node("Player")
	await _frames(5)

	print("Paso 1: resolución interna con factor entero")
	Graphics.set_pixel_height(360)
	var win: Vector2i = root.size
	var factor: int = maxi(1, roundi(win.y / 360.0))
	var size: Vector2i = Graphics.internal_size()
	_check(root.disable_3d, "con pixelado el 3D de la ventana principal debería estar apagado")
	_check(Graphics.pixel_factor() == factor, "factor %d, esperado %d" % [Graphics.pixel_factor(), factor])
	_check(size == Vector2i(ceili(float(win.x) / factor), ceili(float(win.y) / factor)), "tamaño interno raro: %s (ventana %s)" % [size, win])

	print("Paso 2: la cámara espejo sigue al jugador")
	player.rotation.y += 0.7
	player.global_position += Vector3(1.0, 0.0, -1.0)
	await _frames(3)
	var cam: Camera3D = Graphics._cam
	var src: Camera3D = root.get_camera_3d()
	_check(src != null and src.get_parent().get_parent() == player, "la cámara activa no es la del jugador")
	if src:
		_check(cam.global_transform.is_equal_approx(src.global_transform), "la cámara espejo no copió la posición")
		_check(is_equal_approx(cam.fov, src.fov), "la cámara espejo no copió el FOV")

	print("Paso 3: nativa")
	Graphics.set_pixel_height(0)
	_check(not root.disable_3d, "en Nativa el 3D de la ventana debería estar encendido")
	_check(Graphics.internal_size() == root.size, "en Nativa la resolución interna debería ser la de la pantalla")
	Graphics.set_pixel_height(480)
	world.queue_free()
	await _frames(2)

	print("Paso 4: override de renderer")
	var had_override: bool = FileAccess.file_exists(Graphics.RENDERER_OVERRIDE_PATH)
	if not had_override:
		Graphics.request_renderer("gl_compatibility")
		_check(Graphics.next_renderer() == "gl_compatibility", "no se guardó el renderer pedido")
		var cfg: ConfigFile = ConfigFile.new()
		cfg.load(Graphics.RENDERER_OVERRIDE_PATH)
		_check(cfg.get_value("rendering", "renderer/rendering_method.mobile", "") == "gl_compatibility", "falta la variante .mobile en el override")
		DirAccess.remove_absolute(Graphics.RENDERER_OVERRIDE_PATH)

	print("Paso 5: prueba de rendimiento (modo rápido)")
	var bench: Node3D = BENCH.instantiate()
	bench.quick = true
	add_child(bench)
	var waited: float = 0.0
	while bench.results.is_empty() and waited < 20.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	_check(not bench.results.is_empty(), "la prueba de rendimiento no terminó")
	if not bench.results.is_empty():
		_check(bench.results.rows.size() == 4, "se esperaban 4 mediciones, hubo %d" % bench.results.rows.size())
		var text: String = bench.report_text(bench.results)
		_check(text.contains("Máx. enemigos"), "el reporte no trae el resumen")
		_check(bench.get_node("Enemies").get_child_count() == 0, "no se limpiaron los enemigos")
	_check(Graphics.settings.pixel_height == 480, "la prueba no regresó la resolución original")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame
