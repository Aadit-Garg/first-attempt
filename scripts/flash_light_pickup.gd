extends Area2D
@onready var light = $"../player/PointLight2D"
@onready var light2 = $"../player/character_light"

func _on_body_entered(body: Node2D) -> void:
	light.visible=true
	light2.visible=true
	queue_free()
