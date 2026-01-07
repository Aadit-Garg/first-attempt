extends Area2D

@onready var timer: Timer = $Timer
@onready var glitch_rect: Control = get_tree().get_current_scene().get_node("canvas/CanvasLayer/ColorRect")

func _on_body_entered(body: Node2D) -> void:
	print("YOU DIED")
	Engine.time_scale=0.5
	timer.start()

func _on_timer_timeout() -> void:
	Engine.time_scale=1
	GameManager.infection_level=0
	# Reset the infection shader
	if glitch_rect and glitch_rect.material:
		glitch_rect.material.set_shader_parameter("infection_level", 0)
	get_tree().reload_current_scene()
