extends Control

func _on_start_pressed() -> void:
	print("start")
	BgMusic.stream_paused=true
	GameManager.reset_ammo()  # Reset ammo for new game
	get_tree().change_scene_to_file("res://scenes/opening_cutscene.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_credits_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/credits.tscn")
