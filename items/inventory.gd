class_name Inventory
extends Resource
## Tus items, guardados en el celular (user://inventory.tres). Los gastas en
## el duelo (Items gasta el turno) y ganas más como botín al vencer.
##
## Analogía web: un carrito persistido en localStorage: { pocion: 2, ... }.

const PATH: String = "user://inventory.tres"
const MAX_STACK: int = 9

## Catálogo: qué hace cada item. Cambiar números aquí.
## kind: &"heal" (+PV), &"mana" (+PM), &"bomb" (daño fijo al enemigo,
## ignora su bloqueo y lo que resista).
const CATALOG: Dictionary = {
	&"pocion": {"name": "Poción", "desc": "+30 PV", "kind": &"heal", "power": 30},
	&"eter": {"name": "Éter", "desc": "+6 PM", "kind": &"mana", "power": 6},
	&"bomba": {"name": "Bomba de ceniza", "desc": "18 de daño", "kind": &"bomb", "power": 18},
}
## Con qué empiezas la primera vez.
const STARTING: Dictionary = {&"pocion": 2, &"eter": 1, &"bomba": 1}

## Las pruebas automáticas lo apagan para no ensuciar el guardado real.
static var save_enabled: bool = true

## id de item (String) -> cuántos tienes.
@export var counts: Dictionary = {}


static func load_or_new(path: String = PATH) -> Inventory:
	if save_enabled and ResourceLoader.exists(path):
		var saved: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if saved is Inventory:
			return saved
	return starting()


static func starting() -> Inventory:
	var inv: Inventory = Inventory.new()
	for id: StringName in STARTING:
		inv.counts[String(id)] = int(STARTING[id])
	return inv


func save(path: String = PATH) -> void:
	if not save_enabled:
		return
	var err: Error = ResourceSaver.save(self, path)
	if err != OK:
		push_warning("No se pudo guardar el inventario: %s" % error_string(err))


func count(id: StringName) -> int:
	return int(counts.get(String(id), 0))


## Agrega n (sin pasar de MAX_STACK). Devuelve cuántos entraron de verdad.
func add(id: StringName, n: int = 1) -> int:
	if not CATALOG.has(id):
		push_warning("Item desconocido: %s" % id)
		return 0
	var before: int = count(id)
	counts[String(id)] = mini(before + n, MAX_STACK)
	return count(id) - before


## Gasta uno. false si no tenías.
func take(id: StringName) -> bool:
	if count(id) <= 0:
		return false
	counts[String(id)] = count(id) - 1
	return true


## Para la pantalla del duelo: todos los items del catálogo, en orden.
func entries() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for id: StringName in CATALOG:
		var def: Dictionary = CATALOG[id]
		list.append({"id": id, "name": def.name, "desc": def.desc, "count": count(id)})
	return list


## Tira los dados del botín de un enemigo y lo guarda. Devuelve los nombres
## de lo que ganaste (para mostrarlo).
func roll_loot(loot: Dictionary, rng: RandomNumberGenerator) -> PackedStringArray:
	var got: PackedStringArray = []
	for id: Variant in loot:
		var item: StringName = StringName(id)
		if rng.randf() < float(loot[id]) and add(item) > 0:
			got.append(String(CATALOG[item].name))
	return got
