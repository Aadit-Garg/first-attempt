extends Control

func _on_start_pressed() -> void:
	print("start")
	get_tree().change_scene_to_file("res://scenes/opening_cutscene.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
