extends SceneTree
## Arma el "kit de construcción" de zonas: un MeshLibrary con los bloques que
## se pintan en un GridMap (como un tileset 3D). Cada bloque mide 2x2x2 m.
##
## Uso (desde la carpeta del proyecto):
##   godot --headless --path . -s tools/art/build_tile_kit.gd
## Genera: assets/tiles/tile_kit.tres (y los materiales en assets/tiles/materials/).
##
## Para cambiar el look de un bloque basta con reemplazar su PNG en
## assets/tiles/ (ver tools/art/make_tile_textures.py); no hace falta volver a
## correr esto. Solo se vuelve a correr si se agregan o cambian formas.
##
## IMPORTANTE: el número de cada bloque (id) es lo que guarda el GridMap.
## No cambies los ids existentes; agrega bloques nuevos al final.

const OUT: String = "res://assets/tiles/tile_kit.tres"
const MAT_DIR: String = "res://assets/tiles/materials/"

## id, nombre, textura, forma
const BLOCKS: Array = [
	[0, "suelo_ceniza", "ceniza", "cube"],
	[1, "suelo_escoria", "escoria", "cube"],
	[2, "camino", "camino", "cube"],
	[3, "pared_roca", "roca", "cube"],
	[4, "pared_ladrillo", "ladrillo", "cube"],
	[5, "bloque_bajo", "roca", "half"],
	[6, "caja", "madera", "crate"],
	[7, "rampa_baja", "ceniza", "ramp_low"],
	[8, "rampa_alta", "ceniza", "ramp_high"],
	[9, "muro_bajo_ladrillo", "ladrillo", "half"],
	[10, "tronco_quemado", "madera", "trunk"],
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(MAT_DIR)
	var lib: MeshLibrary = MeshLibrary.new()
	var mats: Dictionary = {}
	for b: Array in BLOCKS:
		var id: int = b[0]
		var tex_name: String = b[2]
		if not mats.has(tex_name):
			mats[tex_name] = _material(tex_name)
		var points: PackedVector3Array = _shape_points(b[3])
		lib.create_item(id)
		lib.set_item_name(id, b[1])
		lib.set_item_mesh(id, _prism_mesh(points, b[3], mats[tex_name]))
		var shape: Shape3D
		if b[3] == "cube":
			var box: BoxShape3D = BoxShape3D.new()
			box.size = Vector3(2, 2, 2)
			shape = box
		else:
			var convex: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
			convex.points = points
			shape = convex
		lib.set_item_shapes(id, [shape, Transform3D.IDENTITY])
	var err: Error = ResourceSaver.save(lib, OUT)
	print("tile kit: ", OUT, " -> ", error_string(err))
	quit(0 if err == OK else 1)


func _material(tex_name: String) -> StandardMaterial3D:
	var path: String = MAT_DIR + tex_name + ".tres"
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/tiles/%s.png" % tex_name)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# 32 px cada 2 m, continuo entre bloques vecinos.
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
	mat.roughness = 1.0
	ResourceSaver.save(mat, path)
	mat.take_over_path(path)
	return mat


## Puntos (esquinas) de cada forma, con el centro del bloque en (0, 0, 0):
## va de -1 a 1 en cada eje. Las rampas suben hacia -Z (el "norte" del bloque);
## gíralas en el GridMap para que suban hacia otro lado.
func _shape_points(shape: String) -> PackedVector3Array:
	match shape:
		"cube":
			return _box(Vector3(-1, -1, -1), Vector3(1, 1, 1))
		"half":
			return _box(Vector3(-1, -1, -1), Vector3(1, 0, 1))
		"crate":
			return _box(Vector3(-0.8, -1, -0.6), Vector3(0.8, 0.0, 0.6))
		"trunk":  # tronco delgado; se apilan dos para un árbol de 4 m
			return _box(Vector3(-0.35, -1, -0.35), Vector3(0.35, 1, 0.35))
		"ramp_low":  # de 0 a 1 m de alto
			return PackedVector3Array([
				Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(-1, -1, -1), Vector3(1, -1, -1),
				Vector3(-1, 0, -1), Vector3(1, 0, -1)])
		"ramp_high":  # de 1 a 2 m de alto, macizo por debajo
			return PackedVector3Array([
				Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(-1, -1, -1), Vector3(1, -1, -1),
				Vector3(-1, 0, 1), Vector3(1, 0, 1), Vector3(-1, 1, -1), Vector3(1, 1, -1)])
	return PackedVector3Array()


func _box(a: Vector3, b: Vector3) -> PackedVector3Array:
	var pts: PackedVector3Array = []
	for x: float in [a.x, b.x]:
		for y: float in [a.y, b.y]:
			for z: float in [a.z, b.z]:
				pts.append(Vector3(x, y, z))
	return pts


## Malla cerrada (convexa) a partir de las esquinas.
func _prism_mesh(points: PackedVector3Array, shape: String, mat: Material) -> Mesh:
	if shape == "cube":
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(2, 2, 2)
		box.material = mat
		return box
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri: PackedVector3Array in _hull_triangles(points):
		# Normal plana por cara (bordes duros, como bloques).
		var normal: Vector3 = (tri[2] - tri[0]).cross(tri[1] - tri[0]).normalized()
		for v: Vector3 in tri:
			st.set_normal(normal)
			st.add_vertex(v)
	st.set_material(mat)
	return st.commit()


## Envolvente convexa por fuerza bruta (pocas esquinas): cada trío de puntos
## cuyo plano deja a todos los demás de un lado es una cara.
func _hull_triangles(pts: PackedVector3Array) -> Array[PackedVector3Array]:
	var center: Vector3 = Vector3.ZERO
	for p: Vector3 in pts:
		center += p
	center /= pts.size()
	var tris: Array[PackedVector3Array] = []
	var seen: Dictionary = {}
	var n: int = pts.size()
	for i: int in n:
		for j: int in range(i + 1, n):
			for k: int in range(j + 1, n):
				var a: Vector3 = pts[i]
				var b: Vector3 = pts[j]
				var c: Vector3 = pts[k]
				var normal: Vector3 = (b - a).cross(c - a)
				if normal.length() < 0.0001:
					continue
				normal = normal.normalized()
				var pos: int = 0
				var neg: int = 0
				for m: int in n:
					var d: float = normal.dot(pts[m] - a)
					if d > 0.0001:
						pos += 1
					elif d < -0.0001:
						neg += 1
				if pos > 0 and neg > 0:
					continue
				# La normal debe apuntar hacia afuera.
				if normal.dot(a - center) < 0.0:
					normal = -normal
				var key: String = "%d,%d,%d,%d" % [roundi(normal.x * 100), roundi(normal.y * 100),
						roundi(normal.z * 100), roundi(normal.dot(a) * 100)]
				if seen.has(key):
					continue
				seen[key] = true
				tris.append_array(_face(pts, normal, a))
	return tris


## Triangula la cara (todos los puntos de ese plano) en abanico, en orden.
func _face(pts: PackedVector3Array, normal: Vector3, on_plane: Vector3) -> Array[PackedVector3Array]:
	var face: Array[Vector3] = []
	for p: Vector3 in pts:
		if absf(normal.dot(p - on_plane)) < 0.0001:
			face.append(p)
	var mid: Vector3 = Vector3.ZERO
	for p: Vector3 in face:
		mid += p
	mid /= face.size()
	var u: Vector3 = (face[0] - mid).normalized()
	var v: Vector3 = normal.cross(u)
	face.sort_custom(func(p: Vector3, q: Vector3) -> bool:
		return atan2((p - mid).dot(v), (p - mid).dot(u)) < atan2((q - mid).dot(v), (q - mid).dot(u)))
	var out: Array[PackedVector3Array] = []
	for t: int in range(1, face.size() - 1):
		# Godot usa caras en sentido horario vistas de frente.
		out.append(PackedVector3Array([face[0], face[t + 1], face[t]]))
	return out
