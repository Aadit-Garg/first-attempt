extends CharacterBody2D
@onready var player=get_tree().get_current_scene().get_node("player")
var is_player=false
var radius=50
const SPEED=25
var direction=Vector2.ZERO
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
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
		is_player=false
		get_tree().create_timer(3.0).timeout.connect(_on_freeze_timeout)

func _on_freeze_timeout() -> void:
	kill.collision_mask = org  
	is_frozen = false
	var player_pos=player.global_position
	var eq= (player_pos.x - global_position.x)**2 + (player_pos.y - global_position.y)**2
	if eq<=radius*radius:
		is_player=true
	animated_sprite.play() 
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#if is_frozen:
		
func _physics_process(delta: float) -> void:
	if is_player==true:
		if direction!=Vector2.ZERO:
			if direction.x >0 and direction.y<0:
				animated_sprite.play("walk_up")
			elif direction.x>0 and direction.y>0:
				animated_sprite.play("walk_down")
			elif direction.x<0 and direction.y<0:
				animated_sprite.play("walk_up")
			elif direction.x<0 and direction.y>0:
				animated_sprite.play("walk_down")
			elif direction.y==0:
				if direction.x>0:
					animated_sprite.play("walk_right")
				else:
					animated_sprite.play("walk_left")
		var enemy_to_player=(player.global_position-global_position)
		direction=enemy_to_player.normalized()
		print(direction)
		if direction !=Vector2.ZERO:
			velocity=SPEED*direction
		else:
			velocity.x=move_toward(velocity.x,0,SPEED)
			velocity.y=move_toward(velocity.y,0,SPEED)
		move_and_slide()

func _on_activation_radius_body_entered(body: Node2D) -> void:
	is_player=true
	print("entered")

func _on_deactivation_radius_body_exited(body: Node2D) -> void:
	is_player=false
	print("exited")
