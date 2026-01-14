extends CharacterBody2D

@export var speed := 50.0
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var kill: Area2D = $kill
@onready var enemy_bar: TextureProgressBar = $enemy_bar
@export var item_to_drop_milk:PackedScene=preload("res://scenes/item.tscn")
@export var item_to_drop_ammo:PackedScene=preload("res://scenes/gun_ammo_item.tscn")
@onready var scene=get_tree().get_current_scene()
var is_active := false
var target: Node2D = null
var is_frozen := false
var org_collision_mask: int
var damage=20

func _ready() -> void:
	enemy_bar.visible=false
	enemy_bar.health=100
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
	enemy_bar.visible=true
	enemy_bar.health-=damage
	if enemy_bar.health<=0:
		kill_enemy()
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

func kill_enemy():
	queue_free()
	var random = randf()
	if random>=0.4:
		var item_ammo_instance=item_to_drop_ammo.instantiate()
		item_ammo_instance.global_position = global_position 
		scene.add_child(item_ammo_instance)
	else:
		var item_milk_instance = item_to_drop_milk.instantiate()
		item_milk_instance.global_position = global_position 
		scene.add_child(item_milk_instance)

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
