extends Node2D
@onready var glitch_rect = $"../canvas/CanvasLayer/ColorRect"
@onready var death_screen: ColorRect = $"../CanvasLayer/death_screen"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func death():
	GameManager.infection_level = 0
	glitch_rect.material.set_shader_parameter("infection_level", 0)
	death_screen.visible = true
	get_tree().paused = true

func _on_button_pressed() -> void:
	print("pressed")
	GameManager.infection_level = 0
	GameManager.restore_ammo_checkpoint()
	death_screen.visible = false
	get_tree().paused = false
	get_tree().reload_current_scene()
