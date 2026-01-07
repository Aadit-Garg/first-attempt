extends Area2D

@onready var enemy_dialouge: Node2D = $"../enemy_dialouge"


func _on_body_entered(body: Node2D) -> void:
	enemy_dialouge.called()
	collision_mask=0
	
