extends CharacterBody2D

@export var speed := 50.0
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var kill: Area2D = $kill

var is_active := false
var target: Node2D = null
var is_frozen := false
var org_collision_mask: int

func _ready() -> void:
	org_collision_mask = kill.collision_mask

func _on_activation_radius_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_active = true
		target = body

func _on_deactivation_radius_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_active = false
		target = null

func freeze() -> void:
	if !is_frozen:
		is_frozen = true
		animated_sprite.stop()
		kill.collision_mask = 0
		get_tree().create_timer(3.0).timeout.connect(_on_freeze_timeout)

func _on_freeze_timeout() -> void:
	kill.collision_mask = org_collision_mask
	is_frozen = false
	animated_sprite.play()

func _physics_process(delta: float) -> void:
	if is_frozen or not is_active or target == null:
		return
	
	var direction = (target.global_position - global_position).normalized()
	velocity = direction * speed
	
	# Update animation based on direction
	update_animation(direction)
	
	move_and_slide()

func update_animation(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			animated_sprite.play("walk_right")
		else:
			animated_sprite.play("walk_left")
	else:
		if direction.y > 0:
			animated_sprite.play("walk_down")
		else:
			animated_sprite.play("walk_up")
