extends CharacterBody2D
var original_collision_layer=collision_layer
var original_collision_mask=collision_mask
const SPEED = 130.0
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var point_light: PointLight2D = $PointLight2D
@onready var timer: Timer = $Timer


func _ready() -> void:
	if GlobalScript.checkpoint_pos!=Vector2(-999,-999):
		global_position=GlobalScript.checkpoint_pos

func _physics_process(delta: float) -> void:
	#enter movement
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	#invert controls
	if GameManager.infection_level>=80:
		direction=-direction
	#invinvible ability
	if Input.is_action_pressed("bloom") && GameManager.infection_level<90:
		collision_layer=16
		collision_mask=1       #we will change it when we add enemies
		animated_sprite.modulate.a=0.2
		timer.start()
	var mouse_pos = get_global_mouse_position()
	velocity+=Vector2(delta,delta)#make movement feel same for different fps
	
	
	#light will look here
	point_light.look_at(mouse_pos)
	var look_vec = mouse_pos - global_position
	var angle = look_vec.angle()
	var snapped_angle = snapped(angle, PI / 4)
	var look_dir = Vector2.from_angle(snapped_angle).round()
	
	var x = look_dir.x
	var y = look_dir.y
	
	##horizontal flipping for dl,l,ul
	#if x < 0:
		#animated_sprite.flip_h = true
	#else:
		#animated_sprite.flip_h = false

	#finding which animation to use removed the for loop wasnt worth it
	var anim_name = "running_down"
	match [x, y]:
		[0.0, -1.0]:  anim_name = "running_up"
		[0.0, 1.0]:   anim_name = "running_down"
		[1.0, 0.0]:   anim_name = "running_right"
		[-1.0, 0.0]:  anim_name = "running_left"
		[1.0, -1.0]:  anim_name = "running_ur"
		[-1.0, -1.0]: anim_name = "running_ul"
		[1.0, 1.0]:   anim_name = "running_dr"
		[-1.0, 1.0]:  anim_name = "running_dl"

	#moving the character
	if direction != Vector2.ZERO:
		velocity = direction * SPEED
		animated_sprite.play(anim_name)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)
		animated_sprite.play(anim_name)
		animated_sprite.stop() 

	move_and_slide()


func _on_timer_timeout() -> void:
	collision_layer=original_collision_layer
	collision_mask = original_collision_mask
	animated_sprite.modulate.a=1
