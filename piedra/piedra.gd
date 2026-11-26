extends Node
## Autoload "Piedra": tu piedra mágica. Guarda tu PlayerRecord en el celular
## y reenvía sus señales para que cualquier pantalla las escuche.
## Toda la lógica vive en PlayerRecord y PowerReading (probables sin nodos).
##
## Analogía web: un store global (como un contexto de React) con su
## persistencia en localStorage.

signal reputation_changed(zone: StringName, value: int)
signal level_changed(level: int)

const PATH: String = "user://piedra.tres"

## Las pruebas automáticas lo apagan para no ensuciar el guardado real.
var save_enabled: bool = true
var record: PlayerRecord


func _ready() -> void:
	load_record()


func load_record() -> void:
	var loaded: PlayerRecord = null
	if save_enabled and ResourceLoader.exists(PATH):
		loaded = ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as PlayerRecord
	use_record(loaded if loaded != null else PlayerRecord.new())


func use_record(r: PlayerRecord) -> void:
	if record != null:
		record.reputation_changed.disconnect(reputation_changed.emit)
		record.level_changed.disconnect(level_changed.emit)
	record = r
	record.reputation_changed.connect(reputation_changed.emit)
	record.level_changed.connect(level_changed.emit)


func save() -> void:
	if not save_enabled:
		return
	var err: Error = ResourceSaver.save(record, PATH)
	if err != OK:
		push_warning("No se pudo guardar la piedra: %s" % error_string(err))


## Lee a un rival con tu piedra.
func scan(data: RivalData, memory: RivalMemory) -> PowerReading:
	return PowerReading.read(record.level(), record.power(), data.display_name,
			PowerReading.rival_power(data, memory), data.weakness)
