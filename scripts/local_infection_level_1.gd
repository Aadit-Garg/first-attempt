extends Node2D

var infection_level=1
@onready var timer: Timer = $Timer
@onready var glitch_rect: Control = $"../canvas/CanvasLayer/ColorRect"
@onready var canvas: Control = $"../canvas"
@onready var death_screen: ColorRect = $"../CanvasLayer/death_screen"

func _process(delta: float) -> void:
	#rate of infection
	infection_level=GameManager.infection_level
	if infection_level !=100:
		#state for infection level
		if infection_level>=50 && infection_level!=100:
			glitch_rect.material.set_shader_parameter("infection_level", infection_level)
	else:
		death()

func death():
	GameManager.infection_level = 0
	glitch_rect.material.set_shader_parameter("infection_level", 0)
	death_screen.visible = true
	get_tree().paused = true

func _on_button_pressed() -> void:
	print("pressed")
	GameManager.infection_level = 0
	death_screen.visible = false
	get_tree().paused = false
	get_tree().reload_current_scene()
