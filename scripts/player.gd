extends CharacterBody2D
var original_collision_layer=collision_layer
var original_collision_mask=collision_mask
var bloom_is_ready=true
const SPEED = 70.0
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var point_light: PointLight2D = $PointLight2D
@onready var timer: Timer = $Timer
@onready var timer2: Timer = $Timer2
@onready var footstep_player: AudioStreamPlayer2D = $footstep_player

func _ready() -> void:
	if GlobalScript.checkpoint_pos!=Vector2(-999,-999):
		global_position=GlobalScript.checkpoint_pos
	# Initialize last mouse position to prevent false "moved" detection
	last_mouse_position = get_global_mouse_position()
var last_look_direction := Vector2.DOWN  # Default facing direction
var last_mouse_position := Vector2.ZERO  # Track mouse movement
var using_controller := true  # Start with controller mode (switch to mouse when mouse moves)
func _physics_process(delta: float) -> void:
	#enter movement
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	#invert controls
	if GameManager.infection_level>=80:
		
		direction=-direction
	#invinvible ability
	if Input.is_action_pressed("bloom") && GameManager.infection_level<90 && bloom_is_ready:
		collision_layer=16
		collision_mask=1       #we will change it when we add enemies
		animated_sprite.modulate.a=0.2
		timer.start()
	#var look_direction := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	#var aim_target: Vector2
	#var angle: float
## Check if joystick is being used (deadzone check)
	#if look_direction.length() > 0.2:
		## Controller: Use joystick direction
		#aim_target = global_position + look_direction * 100
		#angle = look_direction.angle()
	#else:
		## Keyboard/Mouse: Use mouse position
		#aim_target = get_global_mouse_position()
		#angle = (aim_target - global_position).angle()
	#point_light.look_at(aim_target)
	#var snapped_angle = snapped(angle, PI / 4)
	#var look_dir = Vector2.from_angle(snapped_angle).round()
	#var x = look_dir.x
	#var y = look_dir.y
	# Check for controller joystick input
	var joy_look := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	
	# Check if mouse has moved (to detect switching from controller to mouse)
	var current_mouse_pos := get_global_mouse_position()
	var mouse_moved := current_mouse_pos.distance_to(last_mouse_position) > 10.0
	if mouse_moved:
		last_mouse_position = current_mouse_pos
		using_controller = false  # Switch to mouse mode

	var aim_target: Vector2
	var angle: float

	if joy_look.length() > 0.2:
		# Controller joystick is being used
		using_controller = true
		last_look_direction = joy_look
		aim_target = global_position + joy_look * 100
		angle = joy_look.angle()
	elif using_controller:
		# Joystick released but was using controller - keep last direction
		aim_target = global_position + last_look_direction * 100
		angle = last_look_direction.angle()
	else:
		# Mouse mode - always follow current mouse position
		aim_target = current_mouse_pos
		var mouse_dir = (aim_target - global_position).normalized()
		if mouse_dir.length() > 0.1:
			last_look_direction = mouse_dir
		angle = (aim_target - global_position).angle()

	point_light.look_at(aim_target)
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
	bloom_is_ready=false
	timer2.start()

func _on_timer_2_timeout() -> void:
	bloom_is_ready=true
