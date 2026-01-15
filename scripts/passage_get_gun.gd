extends Node2D

@onready var check: StaticBody2D = $check
@onready var item_gun: Area2D = $item_gun
@onready var death_screen: ColorRect = $CanvasLayer/death_screen
@onready var transition_rect = $CanvasLayer3/TransitionRect
@onready var animation_player = $CanvasLayer3/AnimationPlayer
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$dialouge.visible=false
	death_screen.visible=false
	GameManager.rate=0
	GameManager.gun_found=false
	GameManager.shooting=false
	GameManager.bullets_in_gun = 5
	GameManager.spare_bullets = 5
	GameManager.save_ammo_checkpoint()
	transition_rect.modulate.a = 0.0
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_item_gun_body_entered(body: Node2D) -> void:
	$dialouge.visible=true
	$dialouge/Label.text="Press Shoot To
	Shoot"
	GameManager.gun_found=true
	GameManager.shooting=true
	check.queue_free()
	item_gun.queue_free()

func _on_exit_body_entered(body: Node2D) -> void:
	animation_player.play("fade")
	await animation_player.animation_finished
	get_tree().change_scene_to_file("res://levels/level_3.tscn")
	animation_player.play_backwards("fade")
	await animation_player.animation_finished
