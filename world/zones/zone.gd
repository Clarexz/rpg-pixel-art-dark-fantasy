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
##
## Analogía web: una página que se monta dentro de un layout fijo.

@export var data: ZoneData


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
