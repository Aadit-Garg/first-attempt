extends CharacterBody2D

@export var speed := 35.0  # Slower but tankier
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var death_screen_tyrant: TextureRect = $death_layer/death_screen_tyrant
@onready var death_audio: AudioStreamPlayer2D = $death_audio
@onready var transition_rect= $CanvasLayer/TransitionRect
@onready var animation_player= $CanvasLayer/AnimationPlayer
@onready var death_screen: ColorRect = $CanvasLayer2/death_screen
@onready var tyrant_kill: Area2D = $tyrant_kill
@onready var hud=get_tree().get_current_scene().get_node("HUD")
var is_active := false
var target: Node2D = null
var is_frozen := false
var org_collision_mask: int

func _ready() -> void:
	hud.visible=true
	transition_rect.modulate.a = 0.0
	death_screen_tyrant.visible=false
	death_screen.visible=false
	org_collision_mask=tyrant_kill.collision_mask

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
		tyrant_kill.collision_mask = 0
		get_tree().create_timer(3.0).timeout.connect(_on_freeze_timeout)

func _on_freeze_timeout() -> void:
	tyrant_kill.collision_mask = org_collision_mask
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
	# Tyrant only has walk_down, walk_left, walk_up animations
	if abs(direction.x) > abs(direction.y):
		animated_sprite.play("walk_left")
		animated_sprite.flip_h = direction.x < 0  # Flip for left movement
	else:
		if direction.y > 0:
			animated_sprite.play("walk_down")
		else:
			animated_sprite.play("walk_up")


func _on_tyrant_kill_body_entered(body: Node2D) -> void:
	if body.name == "player":
		death()

func death():
	hud.visible=false
	death_screen_tyrant.visible=true
	death_audio.play()
	await death_audio.finished #will play the desired audio later
	animation_player.play("fade")
	await animation_player.animation_finished
	death_screen.visible=true
	animation_player.play_backwards("fade")
	await animation_player.animation_finished
	GameManager.infection_level=0
	GameManager.restore_ammo_checkpoint()
	get_tree().paused=true
	

func _on_button_pressed() -> void:
	get_tree().paused=false
	hud.visible=true
	get_tree().reload_current_scene()
