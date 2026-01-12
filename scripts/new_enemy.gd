extends CharacterBody2D
@onready var player=get_tree().get_current_scene().get_node("player")
var is_player=null
const SPEED=25
var direction=Vector2.ZERO


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_player!=null:
		look_at(player.global_position) 

func _physics_process(delta: float) -> void:
	if is_player!=null:
		var enemy_to_player=(player.global_position-global_position)
		direction=enemy_to_player.normalized()
		if direction !=Vector2.ZERO:
			velocity=SPEED*direction
		else:
			velocity.x=move_toward(velocity.x,0,SPEED)
			velocity.y=move_toward(velocity.y,0,SPEED)
		move_and_slide()

func _on_activation_radius_body_entered(body: Node2D) -> void:
	is_player=body
	print("entered")

func _on_deactivation_radius_body_exited(body: Node2D) -> void:
	is_player=null
	print("exited")
