extends Node
## Sonidos placeholder generados por código (sin archivos de audio).
## Es un "autoload": un nodo global que existe siempre, como un singleton o
## un módulo importado en toda la app. Se usa así: Sfx.play(&"hit").
##
## Cada sonido es una onda que calculamos muestra por muestra y guardamos en
## un AudioStreamWAV (como generar un WAV en el navegador con Web Audio).
## Cuando haya sonidos de verdad, se reemplazan por archivos .ogg/.wav.

const RATE: int = 22050
const VOICES: int = 8

## Notas de las 6 casillas de la cuadrícula del duelo (Hz), como los botones
## de la ocarina: fila de arriba aguda, fila de abajo grave.
## 0..2 = arriba izq/centro/der, 3..5 = abajo izq/centro/der.
const NOTE_HZ: Array[float] = [587.33, 698.46, 880.0, 293.66, 349.23, 440.0]

var _streams: Dictionary = {}  # StringName -> AudioStreamWAV
var _notes: Array[AudioStreamWAV] = []
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in VOICES:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams[&"hit"] = _make(0.16, _hit)
	_streams[&"block"] = _make(0.28, _clang.bind(1.0))
	_streams[&"perfect"] = _make(0.45, _clang.bind(1.6))
	_streams[&"hurt"] = _make(0.22, _hurt)
	_streams[&"swing"] = _make(0.14, _swing)
	_streams[&"tick"] = _make(0.05, _tone.bind(1200.0, 0.05))
	_streams[&"windup"] = _make(0.18, _tone.bind(180.0, 0.18))
	_streams[&"fizzle"] = _make(0.35, _fizzle)
	_streams[&"engage"] = _make(0.5, _engage)
	_streams[&"stone"] = _make(0.12, _tone.bind(70.0, 0.12))
	_streams[&"spell"] = _make(0.6, _spell)
	for hz: float in NOTE_HZ:
		_notes.append(_make(0.32, _note.bind(hz)))


func play(sound: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not _streams.has(sound):
		push_warning("Sfx: no existe el sonido %s" % sound)
		return
	_play_stream(_streams[sound], pitch, volume_db)


## Nota de una casilla de la cuadrícula (0..5).
func note(cell: int) -> void:
	_play_stream(_notes[clampi(cell, 0, 5)], 1.0, -2.0)


func _play_stream(stream: AudioStream, pitch: float, volume_db: float) -> void:
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


## Convierte una función f(t) -> muestra (-1..1) en un WAV de 16 bits.
func _make(duration: float, wave: Callable) -> AudioStreamWAV:
	var count: int = int(duration * RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	for i: int in count:
		var t: float = float(i) / RATE
		var v: float = clampf(wave.call(t), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


# --- Recetas de cada sonido (t = segundos desde el inicio) -------------------

func _hit(t: float) -> float:
	var thump: float = sin(TAU * 90.0 * t) * exp(-t * 25.0)
	return (randf_range(-1, 1) * exp(-t * 40.0) * 0.7 + thump) * 0.9


func _clang(t: float, bright: float) -> float:
	var v: float = 0.0
	for hz: float in [820.0, 1270.0, 1930.0]:
		v += sin(TAU * hz * bright * t)
	return v / 3.0 * exp(-t * 11.0) + randf_range(-1, 1) * exp(-t * 80.0) * 0.3


func _hurt(t: float) -> float:
	var square: float = 1.0 if sin(TAU * lerpf(160.0, 90.0, t / 0.22) * t) > 0.0 else -1.0
	return square * 0.45 * exp(-t * 9.0)


func _swing(t: float) -> float:
	return randf_range(-1, 1) * sin(PI * t / 0.14) * 0.35


func _tone(t: float, hz: float, duration: float) -> float:
	return sin(TAU * hz * t) * sin(PI * t / duration) * 0.6


func _note(t: float, hz: float) -> float:
	# Onda "de flauta": senoidal con un poco del armónico, ataque suave.
	var env: float = minf(t / 0.02, 1.0) * exp(-t * 6.0)
	return (sin(TAU * hz * t) + 0.25 * sin(TAU * hz * 2.0 * t)) * env * 0.6


func _fizzle(t: float) -> float:
	return randf_range(-1, 1) * exp(-t * 7.0) * 0.4 * sin(TAU * lerpf(600.0, 80.0, t / 0.35) * t)


func _engage(t: float) -> float:
	var hz: float = lerpf(110.0, 55.0, t / 0.5)
	return (sin(TAU * hz * t) + 0.5 * sin(TAU * hz * 1.5 * t)) * exp(-t * 4.0) * 0.6


func _spell(t: float) -> float:
	var v: float = 0.0
	for hz: float in [440.0, 554.37, 659.25, 880.0]:
		v += sin(TAU * hz * t)
	return v / 4.0 * minf(t / 0.05, 1.0) * exp(-t * 4.0)
