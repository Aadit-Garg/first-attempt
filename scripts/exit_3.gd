extends Area2D
@onready var animation_player= $"../CanvasLayer2/AnimationPlayer"

func _on_body_entered(body: Node2D) -> void:
	animation_player.play("fade")
	await animation_player.animation_finished
	get_tree().change_scene_to_file("res://scenes/final_cutscene.tscn")
	animation_player.play_backwards("fade")
	await animation_player.animation_finished
	
