extends Control
## Credits Intro Scene - Flatline Protocol
## 
## Displays "5 Shades of Gray presents" with fade animations
## then transitions to the opening cutscene.

# =============================================================================
# CONFIGURATION
# =============================================================================

## How long the team name stays visible
const HOLD_DURATION := 2.5

## Fade in/out duration
const FADE_DURATION := 1.5

## Next scene to load
const NEXT_SCENE := "res://scenes/opening_cutscene.tscn"

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var team_name: Label = $CenterContainer/VBoxContainer/TeamName
@onready var presents: Label = $CenterContainer/VBoxContainer/Presents
@onready var fade_overlay: ColorRect = $FadeOverlay

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	"""Start the credits animation sequence."""
	# Ensure labels start invisible
	team_name.modulate.a = 0.0
	presents.modulate.a = 0.0
	fade_overlay.color.a = 0.0
	
	# Start the animation sequence
	await _play_credits_sequence()


func _input(event: InputEvent) -> void:
	"""Allow skipping with Space."""
	if event.is_action_pressed("ui_accept"):
		_skip_to_next_scene()

# =============================================================================
# ANIMATION SEQUENCE
# =============================================================================

func _play_credits_sequence() -> void:
	"""Play the full credits animation."""
	
	# Small initial delay
	await get_tree().create_timer(0.5).timeout
	
	# Fade in team name
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(team_name, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished
	
	# Small delay, then fade in "presents"
	await get_tree().create_timer(0.3).timeout
	
	var tween2 := create_tween()
	tween2.set_ease(Tween.EASE_OUT)
	tween2.set_trans(Tween.TRANS_SINE)
	tween2.tween_property(presents, "modulate:a", 1.0, FADE_DURATION * 0.7)
	await tween2.finished
	
	# Hold on screen
	await get_tree().create_timer(HOLD_DURATION).timeout
	
	# Fade everything out together
	var tween3 := create_tween()
	tween3.set_parallel(true)
	tween3.tween_property(team_name, "modulate:a", 0.0, FADE_DURATION)
	tween3.tween_property(presents, "modulate:a", 0.0, FADE_DURATION)
	await tween3.finished
	
	# Small pause before scene change
	await get_tree().create_timer(0.5).timeout
	
	# Transition to next scene
	_change_scene()


func _skip_to_next_scene() -> void:
	"""Skip credits and go directly to next scene."""
	# Quick fade to black
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.3)
	tween.tween_callback(_change_scene)


func _change_scene() -> void:
	"""Load the next scene."""
	get_tree().change_scene_to_file(NEXT_SCENE)
