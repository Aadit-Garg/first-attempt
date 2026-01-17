extends Node2D

@onready var death_screen: ColorRect = $CanvasLayer/death_screen
@onready var glitch_rect: Control = $canvas/CanvasLayer/ColorRect
@onready var transition_rect = $CanvasLayer2/TransitionRect
@onready var player: CharacterBody2D = $player
@onready var marker_2d: Marker2D = $Marker2D
@onready var key= $key
@onready var org= key.collision_mask
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if GameManager.went_lv3_2:
		player.global_position=marker_2d.position
		key.visible=true
		key.collision_mask=org
	else:
		key.visible=false
		key.collision_mask=0
	GameManager.infection_level=0
	GameManager.rate=4
	glitch_rect.material.set_shader_parameter("infection_level", 0)
	death_screen.visible=false
	transition_rect.modulate.a = 0.0

func _on_exit_body_entered(body: Node2D) -> void:
	glitch_rect.material.set_shader_parameter("infection_level", 0)


func _on_key_body_entered(body: Node2D) -> void:
	print("GOT THE KEYSSSSS")
	GameManager.key_found=true
	key.queue_free()
