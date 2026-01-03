extends CharacterBody2D


const SPEED = 130.0
#const JUMP_VELOCITY = -300.0
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var array =["running_up","running_down","running_right","running_left","running_ur","running_dl","running_ul","running_dr"]
var dx=[0,0,1,-1,1,-1,-1,1]
var dy=[-1,1,0,0,-1,1,-1,1]
func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right","move_up","move_down")
	#direction character will be facing 
	#tried optimizing it but i dont feel it is the best (will work more on this later)
	if direction:
		for i in range(8):
			if direction.x==dx[i] and direction.y==dy[i]:
				if array[i]=="running_left" or array[i]=="running_dl":
					animated_sprite.flip_h=true
				else:
					animated_sprite.flip_h=false
				animated_sprite.play(array[i])
				break;
	else:
		animated_sprite.play("idle")

	if direction == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)
		animated_sprite.play("idle")
	else:
		velocity = direction * SPEED
	move_and_slide()
