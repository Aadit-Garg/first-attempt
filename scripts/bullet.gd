extends Area2D


var speed := 400.0
var direction := Vector2.RIGHT

func _ready() -> void:
	# Auto-destroy after 3 seconds
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_area_entered(area: Area2D) -> void:
	var enemy = area.get_parent()
	if enemy.has_method("freeze"):
		enemy.freeze()
		var org=enemy.get_node("kill").collision_mask
		enemy.get_node("kill").collision_mask=0
	queue_free()  
