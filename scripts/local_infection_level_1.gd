extends Node2D

var infection_level=1
@onready var timer: Timer = $Timer
@onready var glitch_rect: Control = $"../canvas/CanvasLayer/ColorRect"
@onready var death_screen: Control = $"../death_screen"
@onready var canvas: Control = $"../canvas"

func _process(delta: float) -> void:
	#rate of infection
	infection_level=GameManager.infection_level
	if infection_level !=100:
		#state for infection level
		if infection_level>=50 && infection_level!=100:
			glitch_rect.material.set_shader_parameter("infection_level", infection_level)
	else:
		#timer.start()
		#GameManager.infection_level=0
		death()
		#glitch_rect.material.set_shader_parameter("infection_level", 0)
		#print("YOU DIED!!!")

func death():
	timer.start()
	GameManager.infection_level=0
	glitch_rect.material.set_shader_parameter("infection_level", 0)
	canvas.visible=false
	death_screen.visible=true
	print("YOU DIED!!!")
	
func _on_timer_timeout() -> void:
	death_screen.visible=false
	canvas.visible=true
	get_tree().reload_current_scene()
