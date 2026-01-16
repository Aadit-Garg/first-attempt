extends Node2D

@onready var death_screen: ColorRect = $CanvasLayer/death_screen
@onready var glitch_rect: Control = $canvas/CanvasLayer/ColorRect
@onready var transition_rect = $CanvasLayer2/TransitionRect
@onready var animation_player = $CanvasLayer2/AnimationPlayer
@onready var level_3_to_2: Area2D = $level_3_to_2
@onready var exit: Area2D = $Area2D
@onready var org_exit=exit.collision_mask
@onready var org_lv3_2=level_3_to_2.collision_mask
@onready var door_closed: Sprite2D = $door_closed
@onready var door_open: Sprite2D = $level_3_to_2/door_open
@onready var tyrant_scene:=preload("res://scenes/tyrant_enemy.tscn")
@onready var scroll = $scroll
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	exit.collision_mask=0
	#level_3_to_2.collision_mask=0
	GameManager.infection_level=0
	GameManager.rate=2
	scroll.visible=false
	GameManager.decrease=18
	GameManager.shooting=true
	GameManager.gun_found=true
	glitch_rect.material.set_shader_parameter("infection_level", 0)
	death_screen.visible=false
	transition_rect.modulate.a = 0.0
	if GameManager.key_found:
		door_closed.visible=false
		exit.collision_mask=org_exit
		var tyrant = tyrant_scene.instantiate()
		get_tree().get_current_scene().add_child(tyrant)
		tyrant.global_position=$Marker2D.global_position
	else:
		door_closed.visible=true


func _on_label_show_body_entered(body: Node2D) -> void:
	if !GameManager.key_found:
		scroll.visible=true
		get_tree().paused=true
		await get_tree().create_timer(5.0).timeout
		get_tree().paused=false
		scroll.visible=false
		door_open.visible=true
		level_3_to_2.collision_mask=org_lv3_2
	else:
		pass

func _on_level_3_to_2_body_entered(body: Node2D) -> void:
	GameManager.went_lv3_2=true
	animation_player.play("fade")
	await animation_player.animation_finished
	get_tree().change_scene_to_file("res://levels/level_2.tscn")
	animation_player.play_backwards("fade")
	await animation_player.animation_finished
