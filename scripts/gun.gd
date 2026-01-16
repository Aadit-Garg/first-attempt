extends Node2D

signal ammo_changed(bullets_in_gun: int, spare_bullets: int)
signal needs_reload(should_show: bool)
signal reload_started(reload_time: float)
signal reload_progress(progress: float)
signal reload_finished()

@export var bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")
@export var fire_rate := 0.1  # Seconds between shots
@export var magazine_size := 5  # Bullets per magazine
@export var reload_time := 1.5  # Seconds to reload

@onready var shoot_raycast: RayCast2D = $shoot_raycast
@onready var laser_line: Line2D = $LaserLine
@onready var gunshot_sound: AudioStreamPlayer = $GunshotSound
@onready var muzzle_flash: AnimatedSprite2D = $MuzzleFlash
@onready var muzzle_light: PointLight2D = $MuzzleLight

var can_shoot = GameManager.shooting
var gun_visible=GameManager.gun_found
var is_reloading := false
var bullets_in_gun: int  # Current bullets in magazine
var spare_bullets: int   # Spare bullets available
var reload_elapsed := 0.0

func _ready() -> void:
	if !gun_visible:
		visible=false
	muzzle_flash.visible = false
	muzzle_light.visible = false
	# Load ammo from GameManager if it exists, otherwise use defaults
	if GameManager.bullets_in_gun >= 0:
		bullets_in_gun = GameManager.bullets_in_gun
		spare_bullets = GameManager.spare_bullets
	else:
		# First time loading - use default values
		bullets_in_gun = magazine_size  # Start with full magazine (5)
		spare_bullets = magazine_size   # Start with spare bullets (5)
	# Emit initial ammo state
	call_deferred("_emit_ammo_state")
	# Initialize last mouse position to prevent false "moved" detection
	last_mouse_position = get_global_mouse_position()

func _emit_ammo_state() -> void:
	ammo_changed.emit(bullets_in_gun, spare_bullets)
	needs_reload.emit(bullets_in_gun == 0 and spare_bullets > 0)
var last_look_direction = Vector2(0,0)
var current_aim_target = Vector2(0,0)
var last_mouse_position := Vector2.ZERO  # Track mouse movement
var using_controller := true  # Start with controller mode (switch to mouse when mouse moves)
func _process(delta: float) -> void:
	can_shoot = GameManager.shooting
	gun_visible=GameManager.gun_found
	if gun_visible:
		visible=true
	else:
		visible=false
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
	
	if joy_look.length() > 0.2:
		# Controller joystick is being used
		using_controller = true
		last_look_direction = joy_look.normalized()
		current_aim_target = global_position + joy_look * 100
	elif using_controller:
		# Joystick released but was using controller - keep last direction
		current_aim_target = global_position + last_look_direction * 100
	else:
		# Mouse mode - always follow current mouse position
		current_aim_target = current_mouse_pos
		var mouse_dir = (current_aim_target - global_position).normalized()
		if mouse_dir.length() > 0.1:
			last_look_direction = mouse_dir
	look_at(current_aim_target)
	if shoot_raycast.is_colliding():
		var cp = shoot_raycast.get_collision_point()
		var local_cp = to_local(cp)
		laser_line.points[1] = local_cp
	
	# Update reload progress
	if is_reloading:
		reload_elapsed += delta
		var progress = clamp(reload_elapsed / reload_time, 0.0, 1.0)
		reload_progress.emit(progress)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Shoot") and can_shoot and not is_reloading:
		if bullets_in_gun > 0:
			shoot()
	
	if event.is_action_pressed("Reload") and not is_reloading:
		if bullets_in_gun < magazine_size and spare_bullets > 0:
			reload()

func shoot() -> void:
	GameManager.shooting = false
	bullets_in_gun -= 1
	print("shooting - ammo: ", bullets_in_gun, "/", spare_bullets)
	gunshot_sound.pitch_scale = randf_range(0.9, 1.1)
	gunshot_sound.play()
	
	# Save ammo state to GameManager for persistence across levels
	GameManager.bullets_in_gun = bullets_in_gun
	GameManager.spare_bullets = spare_bullets
	
	# Play muzzle flash and light
	muzzle_flash.visible = true
	muzzle_flash.play("default")
	muzzle_light.visible = true
	
	# Turn off light quickly (0.04 sec)
	await get_tree().create_timer(0.04).timeout
	muzzle_light.visible = false
	
	# Update HUD
	ammo_changed.emit(bullets_in_gun, spare_bullets)
	needs_reload.emit(bullets_in_gun == 0 and spare_bullets > 0)
	
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = last_look_direction
	bullet.rotation = bullet.direction.angle()
	
	get_tree().current_scene.add_child(bullet)
	
	# Hide muzzle flash after animation
	await get_tree().create_timer(0.24).timeout
	muzzle_flash.visible = false
	muzzle_flash.stop()
	
	# Fire rate cooldown
	await get_tree().create_timer(fire_rate).timeout
	GameManager.shooting = true

func reload() -> void:
	if is_reloading or spare_bullets <= 0:
		return
	
	is_reloading = true
	reload_elapsed = 0.0
	print("reloading...")
	
	needs_reload.emit(false)
	reload_started.emit(reload_time)
	
	await get_tree().create_timer(reload_time).timeout
	
	var bullets_needed = magazine_size - bullets_in_gun
	var bullets_to_load = min(bullets_needed, spare_bullets)
	
	bullets_in_gun += bullets_to_load
	spare_bullets -= bullets_to_load
	
	is_reloading = false
	print("reloaded - ammo: ", bullets_in_gun, "/", spare_bullets)
	
	GameManager.bullets_in_gun = bullets_in_gun
	GameManager.spare_bullets = spare_bullets
	
	# Update HUD
	reload_finished.emit()
	ammo_changed.emit(bullets_in_gun, spare_bullets)

func add_spare_ammo(amount: int) -> void:
	spare_bullets += amount

	GameManager.bullets_in_gun = bullets_in_gun
	GameManager.spare_bullets = spare_bullets
	ammo_changed.emit(bullets_in_gun, spare_bullets)
