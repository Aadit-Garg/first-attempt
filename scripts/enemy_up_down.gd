extends Node2D
const SPEED=50
var direction=1
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray_cast_down: RayCast2D = $RayCast_down
@onready var ray_cast_up: RayCast2D = $RayCast_up

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if ray_cast_down.is_colliding():
		direction=-1
		animated_sprite.play("walk_up")
	if ray_cast_up.is_colliding():
		direction=1
		animated_sprite.play("walk_down")
	position.y+=SPEED*direction*delta
