extends Control
## Muestra la simulación de 10 duelos como texto (para verla en el editor:
## abre tools/sim/rival_sim.tscn y dale F6).

func _ready() -> void:
	var label: RichTextLabel = $Scroll/Text
	var text: String = "\n".join(RivalSim.new().run().lines())
	label.text = text
	print(text)
