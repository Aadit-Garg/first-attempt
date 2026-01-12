extends Node2D
const SPEED=50
var direction=1
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray_cast_down: RayCast2D = $RayCast_down
@onready var ray_cast_up: RayCast2D = $RayCast_up
@onready var kill: Area2D = $kill
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
	if ray_cast_down.is_colliding():
		direction=-1
		animated_sprite.play("walk_up")
	if ray_cast_up.is_colliding():
		direction=1
		animated_sprite.play("walk_down")
	position.y+=SPEED*direction*delta
