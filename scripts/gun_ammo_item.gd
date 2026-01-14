extends Area2D
@export var ammo_amount :int= randi_range(3, 7)
func _on_body_entered(body: Node2D) -> void:
	if body.name == "player":
		var gun = body.get_node("gun")
		if gun:
			gun.add_spare_ammo(ammo_amount)
		queue_free()
