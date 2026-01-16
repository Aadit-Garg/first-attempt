extends Node2D

@onready var death_screen: ColorRect = $CanvasLayer/death_screen
@onready var glitch_rect: Control = $canvas/CanvasLayer/ColorRect
@onready var transition_rect = $CanvasLayer2/TransitionRect
@onready var animation_player = $CanvasLayer2/AnimationPlayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GameManager.infection_level=0
	GameManager.rate=2
	GameManager.decrease=18
	GameManager.shooting=true
	GameManager.gun_found=true
	GameManager.save_ammo_checkpoint()
	glitch_rect.material.set_shader_parameter("infection_level", 0)
	death_screen.visible=false
	transition_rect.modulate.a = 0.0
	#if !GameManager.key_found:
		#door_closed.visible=true
		#exit.collision_mask=0

func _on_exit_body_entered(body: Node2D) -> void:
	animation_player.play("fade")
	await animation_player.animation_finished
	get_tree().change_scene_to_file("res://scenes/final_cutscene.tscn")
	animation_player.play_backwards("fade")
	await animation_player.animation_finished
