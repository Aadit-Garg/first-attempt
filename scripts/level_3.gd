extends Node2D

@onready var death_screen: ColorRect = $CanvasLayer/death_screen
@onready var glitch_rect: Control = $canvas/CanvasLayer/ColorRect

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GameManager.infection_level=0
	GameManager.rate=6
	GameManager.decrease=10
	glitch_rect.material.set_shader_parameter("infection_level", 0)
	death_screen.visible=false
