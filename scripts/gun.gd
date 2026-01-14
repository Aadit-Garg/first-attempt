extends Node2D

signal ammo_changed(bullets_in_gun: int, spare_bullets: int)
signal needs_reload(should_show: bool)
signal reload_started(reload_time: float)
signal reload_progress(progress: float)
signal reload_finished()

@export var bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")
@export var fire_rate := 0.0  # Seconds between shots
@export var magazine_size := 5  # Bullets per magazine
@export var reload_time := 1.5  # Seconds to reload

@onready var shoot_raycast: RayCast2D = $shoot_raycast
@onready var laser_line: Line2D = $LaserLine
@onready var gunshot_sound: AudioStreamPlayer = $GunshotSound
@onready var muzzle_flash: AnimatedSprite2D = $MuzzleFlash
@onready var muzzle_light: PointLight2D = $MuzzleLight

var can_shoot := true
var is_reloading := false
var bullets_in_gun: int  # Current bullets in magazine
var spare_bullets: int   # Spare bullets available
var reload_elapsed := 0.0

func _ready() -> void:
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

func _emit_ammo_state() -> void:
	ammo_changed.emit(bullets_in_gun, spare_bullets)
	needs_reload.emit(bullets_in_gun == 0 and spare_bullets > 0)

func _process(delta: float) -> void:
	look_at(get_global_mouse_position())
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
	can_shoot = false
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
	bullet.direction = (get_global_mouse_position() - global_position).normalized()
	bullet.rotation = bullet.direction.angle()
	
	get_tree().current_scene.add_child(bullet)
	
	# Hide muzzle flash after animation
	await get_tree().create_timer(0.24).timeout
	muzzle_flash.visible = false
	muzzle_flash.stop()
	
	# Fire rate cooldown
	await get_tree().create_timer(fire_rate).timeout
	can_shoot = true

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
