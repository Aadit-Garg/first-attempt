extends Area2D

func _on_body_entered(body: Node2D) -> void:
	GameManager.reduce_infection()
	queue_free()
