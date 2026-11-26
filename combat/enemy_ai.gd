class_name EnemyAI
extends RefCounted
## Qué movimiento usa un enemigo en su turno. A propósito NO es azar puro:
## sigue su patrón en orden (y otro patrón cuando le queda poca vida), para
## que el jugador pueda aprenderlo. El lado de cada golpe sí es al azar.
##
## Función pura: misma entrada, misma salida (como un selector de Redux).
## Solo recibe la ficha de ESTE enemigo; nunca a otros enemigos.

## Por debajo de esta fracción de vida usa pattern_low.
const LOW_HP: float = 0.5
## Si la ficha no tiene movimientos (p. ej. el cubo de prueba), usa este.
static var _fallback: EnemyMove = EnemyMove.make(&"golpe", "Golpe", EnemyMove.Kind.SIMPLE, 12)


## step = cuántos movimientos lleva este duelo (0, 1, 2...).
static func choose(data: EnemyData, step: int, hp_ratio: float) -> EnemyMove:
	var pat: PackedStringArray = data.pattern
	if hp_ratio < LOW_HP and not data.pattern_low.is_empty():
		pat = data.pattern_low
	if pat.is_empty():
		return data.moves[step % data.moves.size()] if not data.moves.is_empty() else _fallback
	var m: EnemyMove = data.move_by_id(StringName(pat[step % pat.size()]))
	return m if m != null else _fallback


## Lados de un combo: nunca el mismo dos veces seguidas.
static func combo_sides(hits: int, rng: RandomNumberGenerator) -> Array[int]:
	var sides: Array[int] = []
	var last: int = -1
	for i: int in hits:
		var s: int = rng.randi_range(0, 2)
		if s == last:
			s = (s + 1 + rng.randi_range(0, 1)) % 3
		sides.append(s)
		last = s
	return sides


## Lado falso de una finta (distinto del real).
static func feint_side(real_side: int, rng: RandomNumberGenerator) -> int:
	return (real_side + 1 + rng.randi_range(0, 1)) % 3
