class_name RivalRegistry
extends Resource
## Guarda la memoria de cada rival, una por id, en el celular.
##
## Es solo un "cajón" con muchas memorias separadas: no tiene jerarquía, no
## ordena rivales, y record() toca ÚNICAMENTE la memoria del rival del duelo.
## Analogía web: un Map<rivalId, Memory> persistido en localStorage.

const PATH: String = "user://rivals.tres"

## Las pruebas automáticas lo apagan para no ensuciar el guardado real.
static var save_enabled: bool = true

@export var memories: Dictionary = {}


static func load_or_new(path: String = PATH) -> RivalRegistry:
	if save_enabled and ResourceLoader.exists(path):
		var saved: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if saved is RivalRegistry:
			return saved
	return RivalRegistry.new()


func save(path: String = PATH) -> void:
	if not save_enabled:
		return
	var err: Error = ResourceSaver.save(self, path)
	if err != OK:
		push_warning("No se pudo guardar la memoria de los rivales: %s" % error_string(err))


## La memoria de un rival (se crea vacía la primera vez que te ve).
func memory_for(rival_id: StringName) -> RivalMemory:
	var key: String = String(rival_id)
	var m: RivalMemory = memories.get(key) as RivalMemory
	if m == null:
		m = RivalMemory.new()
		m.rival_id = rival_id
		memories[key] = m
	return m


## Entrega el resultado de un duelo a la memoria de SU rival y a nadie más.
func record(e: Encounter) -> void:
	memory_for(e.rival_id).record(e)
