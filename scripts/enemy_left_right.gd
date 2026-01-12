extends Node2D

const SPEED =70
var direction=-1

@onready var ray_cast_left: RayCast2D = $RayCast_left
@onready var ray_cast_right: RayCast2D = $RayCast_right
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var is_frozen=false
# Called every frame. 'delta' is the elapsed time since the previous frame.
func freeze() -> void:
	is_frozen = true
	animated_sprite.stop() 

func _process(delta: float) -> void:
	if is_frozen:
		return
	if ray_cast_right.is_colliding():
		direction=-1
		animated_sprite.flip_h=false
		
	if ray_cast_left.is_colliding():
		direction=1
		animated_sprite.flip_h=true
		
	position.x+=SPEED * direction * delta
