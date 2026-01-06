extends Area2D

func _on_body_entered(body: Node2D) -> void:
	GameManager.infection_level=0
	get_tree().change_scene_to_file("res://levels/level_3.tscn")
