extends Area2D

@onready var timer: Timer = $Timer
@onready var death_screen= get_tree().get_current_scene().get_node("local_infection_level")

func _on_body_entered(body: Node2D) -> void:
	print("YOU DIED")
	death_screen.death()
	
