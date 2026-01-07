extends Area2D
@onready var surprise: Node2D = $"../surprise"


func _on_body_entered(body: Node2D) -> void:
	surprise.called()
