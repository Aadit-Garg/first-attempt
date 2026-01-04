extends Sprite2D
@onready var game_manager: Node = %GameManager
@onready var marker: Marker2D = $Marker2D

func _on_body_entered(body: Node2D) -> void:
	print("Checkpoint!!")
	print(marker.global_position)
	GlobalScript.checkpoint_pos=marker.global_position
