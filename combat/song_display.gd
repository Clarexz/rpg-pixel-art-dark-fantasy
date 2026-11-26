class_name SongDisplay
extends Control
## Muestra la "canción" de un hechizo como una fila de mini-cuadrículas 2x3,
## cada una con la casilla que toca iluminada (como las partituras de la
## ocarina). Las notas ya tocadas se ponen verdes.
## Sin pistas (hints = false) solo se ven casillas vacías: tienes que recordarla.

var song: Array = []
var done: int = 0
var hints: bool = true

const CELL: float = 26.0
const CELL_GAP: float = 4.0
const NOTE_GAP: float = 34.0


func _draw() -> void:
	if song.is_empty():
		return
	var note_w: float = CELL * 3.0 + CELL_GAP * 2.0
	var note_h: float = CELL * 2.0 + CELL_GAP
	var total: float = song.size() * note_w + (song.size() - 1) * NOTE_GAP
	var start: Vector2 = Vector2((size.x - total) * 0.5, (size.y - note_h) * 0.5)
	draw_rect(Rect2(start - Vector2(14, 10), Vector2(total + 28, note_h + 20)), Color(0, 0, 0, 0.5))
	for i: int in song.size():
		var origin: Vector2 = start + Vector2(i * (note_w + NOTE_GAP), 0)
		var target: int = song[i]
		for cell: int in 6:
			var pos: Vector2 = origin + Vector2((cell % 3) * (CELL + CELL_GAP), floorf(cell / 3.0) * (CELL + CELL_GAP))
			var color: Color = Color(1, 1, 1, 0.15)
			if cell == target and (hints or i < done):
				if i < done:
					color = Color(0.4, 1.0, 0.5)
				elif i == done:
					color = Color(1.0, 0.85, 0.3)
				else:
					color = Color(1, 1, 1, 0.75)
			draw_rect(Rect2(pos, Vector2(CELL, CELL)), color)
