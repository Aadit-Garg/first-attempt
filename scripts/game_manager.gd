extends Node
var infection_level=0.0
var rate=10
var decrease=15
@onready var glitch_rect: ColorRect  = $"../canvas/CanvasLayer/ColorRect"

func _process(delta: float) -> void:
	#rate of infection
	infection_level += delta * rate 
	infection_level = clamp(infection_level, 0.0, 100.0)
	#state for infection level
	if infection_level>=50:
		glitch_rect.material.set_shader_parameter("infection_level", infection_level)
	if infection_level==100:
		print("YOU DIED!!!")

#how it will work for health items
func _on_interactive_items_body_entered(body: Node2D) -> void:
	infection_level-=decrease
	infection_level=clamp(infection_level,0,100)
