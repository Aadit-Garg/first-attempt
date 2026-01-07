extends Area2D
@onready var infection_dialouge: Node2D = $"../infection_dialouge"
@onready var glitch_rect: Control = $"../canvas/CanvasLayer/ColorRect"
@onready var canvas: Control = $"../canvas"

func _on_body_entered(body: Node2D) -> void:
	infection_dialouge.called()
	glitch_rect.material.set_shader_parameter("infection_level", 69)
	collision_mask=0
