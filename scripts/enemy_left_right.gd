extends Node2D

const SPEED =70
var direction=-1
@onready var kill: Area2D = $kill
@onready var ray_cast_left: RayCast2D = $RayCast_left
@onready var ray_cast_right: RayCast2D = $RayCast_right
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var org
var is_frozen=false
func _ready() -> void:
	org=get_node("kill").collision_mask
# Called every frame. 'delta' is the elapsed time since the previous frame.
func freeze() -> void:
	if !is_frozen:
		is_frozen = true
		animated_sprite.stop()
		kill.collision_mask = 0 
		get_tree().create_timer(3.0).timeout.connect(_on_freeze_timeout)

func _on_freeze_timeout() -> void:
	kill.collision_mask = org  
	is_frozen = false
	animated_sprite.play() 

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
