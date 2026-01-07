extends Node2D

@onready var death_screen: ColorRect = $CanvasLayer/death_screen

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GameManager.infection_level=0
	GameManager.rate=5
	GameManager.decrease=15
	death_screen.visible=false
