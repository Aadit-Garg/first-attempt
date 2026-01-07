extends Area2D
@onready var flash_light: Node2D = $"../Flash_light"

func _on_body_entered(body: Node2D) -> void:
	flash_light.called()
	collision_mask=0
