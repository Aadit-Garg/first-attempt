extends Area2D
@onready var animation_player = $"../CanvasLayer2/AnimationPlayer"

func _on_body_entered(body: Node2D) -> void:
	GameManager.infection_level=0
	animation_player.play("fade")
	await animation_player.animation_finished
	if GameManager.went_lv3_2:
		get_tree().change_scene_to_file("res://levels/level_3.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/passage_get_gun.tscn")
	animation_player.play_backwards("fade")
	await animation_player.animation_finished
