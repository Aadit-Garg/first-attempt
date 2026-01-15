extends Node2D
const SPEED=50
var direction=1
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray_cast_down: RayCast2D = $RayCast_down
@onready var ray_cast_up: RayCast2D = $RayCast_up
@onready var kill: Area2D = $kill
@onready var enemy_bar: TextureProgressBar = $enemy_bar
@export var item_to_drop_milk:PackedScene=preload("res://scenes/item.tscn")
@export var item_to_drop_ammo:PackedScene=preload("res://scenes/gun_ammo_item.tscn")
@onready var scene=get_tree().get_current_scene()
var org
var is_frozen=false
var damage=20
func _ready() -> void:
	enemy_bar.visible=false
	enemy_bar.health=100
	org=get_node("kill").collision_mask
# Called every frame. 'delta' is the elapsed time since the previous frame.
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
	kill.collision_mask = org  
	is_frozen = false
	animated_sprite.play() 

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
