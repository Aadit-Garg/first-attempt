extends Node2D

@export var bullet_scene: PackedScene=preload("res://scenes/bullet.tscn")  # Assign bullet.tscn in the inspector
@export var fire_rate := 0  # Seconds between shots

var can_shoot := true

func _process(delta: float) -> void:
	look_at(get_global_mouse_position())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Shoot") and can_shoot:
		shoot()

func shoot() -> void:
	can_shoot = false
	print("shooting")
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = (get_global_mouse_position() - global_position).normalized()
	bullet.rotation = bullet.direction.angle()
	
	get_tree().current_scene.add_child(bullet)
	
	# Fire rate cooldown
	await get_tree().create_timer(fire_rate).timeout
	can_shoot = true
