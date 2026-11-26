class_name RivalDialogue
extends RefCounted
## Qué dice un rival al empezar el duelo. Solo texto: no cambia cómo pelea.
##
## Usa su propia memoria (lo que vivió contigo) y, como sabor, el título de
## fama del jugador que le da la piedra (algo del JUGADOR, no de otro rival).
## Es la mecánica más cercana a la línea de la patente, por eso está
## aislada aquí y se puede apagar con USE_FAME (ver docs/rivales-y-piedra.md).

const USE_FAME: bool = true


static func greeting(data: RivalData, memory: RivalMemory, tactics: RivalTactics,
		fame_title: String = "") -> String:
	var line: String
	if memory == null or memory.duels == 0:
		line = data.line_first_meet if not data.line_first_meet.is_empty() \
				else "¿Un intruso? Veamos de qué estás hecho."
		if USE_FAME and not fame_title.is_empty():
			line += " Así que tú eres %s." % fame_title
		return line
	match memory.last_result:
		"fled":
			line = "La última vez huiste." if memory.player_flees == 1 \
					else "Ya huiste %d veces." % memory.player_flees
		"win":
			line = "Me venciste una vez. No habrá una segunda." if memory.player_wins == 1 \
					else "%d veces me has tumbado. Ya te estudié." % memory.player_wins
		"lose":
			line = "¿Volviste? La última vez caíste rápido." if data.pride >= 0.5 \
					else "Volviste. Eso es valor... o necedad."
		_:
			line = "Otra vez tú."
	if not memory.scars.is_empty():
		line += " Aún me arde tu %s." % memory.scars[-1]
	if tactics != null:
		if tactics.guard_side != -1:
			line += " Siempre atacas por %s..." % RivalMemory.SIDE_NAMES[tactics.guard_side]
		elif not tactics.resists.is_empty():
			line += " Tu %s ya no me asusta." % tactics.resists
	return line


static func defeated(data: EnemyData) -> String:
	return data.line_defeated
