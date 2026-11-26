class_name RivalMemory
extends Resource
## Lo que un rival recuerda de ti entre duelos. Se guarda en el celular.
## Prototipo: un solo rival, una sola memoria. Después habrá una por rival.
##
## Analogía web: un objeto que serializas a localStorage después de cada pelea.

const PATH: String = "user://rival_memory.tres"
const SIDE_NAMES: Array[String] = ["la izquierda", "el centro", "la derecha"]
## Desde cuántos duelos el rival empieza a cubrir tu lado favorito.
const ADAPT_AFTER_DUELS: int = 3

## Las pruebas automáticas lo apagan para no ensuciar el guardado real.
static var save_enabled: bool = true

@export var duels: int = 0
## "", "win" (ganaste tú), "lose" (perdiste) o "fled" (huiste).
@export var last_result: String = ""
## Cuántas veces has atacado por la izquierda, el centro y la derecha.
@export var attack_counts: Array[int] = [0, 0, 0]


static func load_or_new() -> RivalMemory:
	if save_enabled and ResourceLoader.exists(PATH):
		var saved: Resource = ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		if saved is RivalMemory:
			return saved
	return RivalMemory.new()


func save() -> void:
	if not save_enabled:
		return
	var err: Error = ResourceSaver.save(self, PATH)
	if err != OK:
		push_warning("No se pudo guardar la memoria del rival: %s" % error_string(err))


## Tu lado favorito para atacar (0..2), o -1 si todavía no se nota.
func favorite_side() -> int:
	var total: int = attack_counts[0] + attack_counts[1] + attack_counts[2]
	if total < 4:
		return -1
	var best: int = 0
	for i: int in 3:
		if attack_counts[i] > attack_counts[best]:
			best = i
	return best


## ¿Ya te conoce lo suficiente como para cubrir tu lado favorito?
func adapts() -> bool:
	return duels >= ADAPT_AFTER_DUELS and favorite_side() != -1


## Lo primero que dice el rival al empezar el duelo.
func greeting() -> String:
	var line: String
	match last_result:
		"fled":
			line = "La última vez huiste."
		"win":
			line = "Me venciste una vez. No habrá una segunda."
		"lose":
			line = "¿Volviste? La última vez caíste rápido."
		_:
			line = "¿Un intruso? Veamos de qué estás hecho."
	if adapts():
		line += " Siempre atacas por %s..." % SIDE_NAMES[favorite_side()]
	return line
