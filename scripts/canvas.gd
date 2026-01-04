extends Control
#var bg_color=Color("#0a0a12")
#var glitch=false
#var infection_level=0
#@onready var game_manager: Node = %GameManager
#@onready var canvas_modulate: CanvasModulate = $CanvasModulate
## Called every frame. 'delta' is the elapsed time since the previous frame.
##working more on this once the tileset is complete
#func _process(delta: float) -> void:
	#infection_level=game_manager.infection(delta,infection_level)
	#if infection_level>=50:
		#glitch=true;
	#if glitch:
		#if randf() > 0.5:
			#canvas_modulate.color = Color(randf(), randf(), randf()) * 0.5 # Random tint
		#else:
			#canvas_modulate.color = bg_color
		#
	#else:
		#canvas_modulate.color = bg_color
