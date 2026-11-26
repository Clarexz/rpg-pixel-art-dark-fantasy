class_name Zone
extends Node3D
## Una zona del mundo: el terreno, la luz y quién vive ahí. NO tiene jugador,
## HUD ni duelo: eso vive en World (world/world.tscn), que carga una zona a la
## vez en su ranura. Así, cambiar de zona es cambiar de "página" sin tocar el
## resto (más adelante: streaming de zonas).
##
## Lo que una zona debe tener:
## - `data`: su ficha (ZoneData).
## - Un Marker3D llamado `PlayerStart`: dónde apareces al entrar.
## - Sus enemigos en el grupo "enemy" (Enemy ya se mete solo).
## - (Opcional) un NavigationRegion3D llamado `Navigation`: el mapa por donde
##   caminan los enemigos para rodear paredes. Se calcula solo al cargar la
##   zona a partir de lo que esté en el grupo "navmesh_source" (el terreno).
##
## Analogía web: una página que se monta dentro de un layout fijo.

@export var data: ZoneData


## Se emite cuando el mapa de navegación ya está listo (o si no hay).
signal navigation_ready

## true cuando el mapa de navegación ya está calculado.
var navigation_baked: bool = false


func _ready() -> void:
	_bake_navigation()


func _bake_navigation() -> void:
	var nav: NavigationRegion3D = get_node_or_null("Navigation") as NavigationRegion3D
	if nav and nav.navigation_mesh and nav.navigation_mesh.get_polygon_count() == 0:
		# Esperamos a que los bloques CSG armen su forma (lo hacen "al final
		# del cuadro", un instante después de entrar al árbol). Se calcula al
		# cargar (rápido en zonas chicas); con streaming se podrá guardar ya
		# calculado.
		await get_tree().process_frame
		await get_tree().physics_frame
		if not is_inside_tree():
			return
		nav.bake_navigation_mesh(false)
	navigation_baked = true
	navigation_ready.emit()


## Id de la zona (para la fama por zona de la piedra).
func zone_id() -> StringName:
	return data.id if data else &""


## Dónde aparece el jugador al entrar.
func player_start() -> Transform3D:
	var marker: Node3D = get_node_or_null("PlayerStart") as Node3D
	return marker.global_transform if marker else global_transform


## Los enemigos de ESTA zona (no los de otras zonas cargadas).
func enemies() -> Array[Enemy]:
	var list: Array[Enemy] = []
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		if is_ancestor_of(node):
			list.append(node as Enemy)
	return list
