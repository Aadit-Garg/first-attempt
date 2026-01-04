extends Node
var infection_level=0.0
var rate=10
var decrease=15
@onready var glitch_rect: ColorRect  = $"../canvas/CanvasLayer/ColorRect"

func _process(delta: float) -> void:
	infection_level += delta * rate # Increase infection
	# Clamp it so it doesn't go below 0 or above 100
	infection_level = clamp(infection_level, 0.0, 100.0)
	
	# UPDATE THE SHADER
	# We send the number straight to the GPU
	if infection_level>=50:
		glitch_rect.material.set_shader_parameter("infection_level", infection_level)
	if infection_level==100:
		print("YOU DIED!!!")
func _on_interactive_items_body_entered(body: Node2D) -> void:
	infection_level-=decrease
	infection_level=clamp(infection_level,0,100)
