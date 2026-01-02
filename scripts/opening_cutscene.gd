extends Control
## Opening Cutscene Script - Flatline Protocol
## 
## This script handles the opening cutscene's "Selective Hearing" dialogue system.
## The child hears muffled speech with traumatic keywords piercing through.
##
## Features:
## - Typewriter text effect using Tween
## - Mumble audio that plays during text reveal
## - Camera zoom for claustrophobic effect
## - Input handling (Space to skip/advance)
## - Fade to black and scene transition

# =============================================================================
# CONFIGURATION
# =============================================================================

## Characters revealed per second during typewriter effect
const TYPE_SPEED: float = 30.0

## Camera zoom configuration
const ZOOM_START := Vector2(1.0, 1.0)
const ZOOM_END := Vector2(1.2, 1.2)
const ZOOM_DURATION := 25.0  # Total scene duration in seconds

## Fade transition settings
const FADE_DURATION := 2.0  # Duration of fade to black

## Next scene to load after cutscene completes
const NEXT_SCENE := "res://scenes/game.tscn"

## Input action for advancing dialogue (fallback to ui_accept if not defined)
const ADVANCE_ACTION := "ui_accept"

# =============================================================================
# DIALOGUE DATA
# =============================================================================

## Dialogue lines using "Selective Hearing" BBCode formatting
## The child only hears fragments - traumatic words pierce through the fog
## "..." represents muffled, incomprehensible speech
var dialogue_lines: Array[String] = [
	"[color=#555555]...... results ......[/color] [color=#ff0000][shake rate=20 level=10]SERIOUS[/shake][/color] [color=#555555]......[/color]",
	
	"[color=#555555]...... aggressive ......[/color] [color=#ff0000][shake rate=20 level=10]DISEASE[/shake][/color] [color=#555555]...... brain ......[/color]",
	
	"[color=#555555]...... prognosis ......[/color] [color=#ff0000][shake rate=20 level=10]SIX MONTHS[/shake][/color] [color=#555555]...... at most ......[/color]",
	
	"[color=#555555]...... manage ......[/color] [color=#ff0000][shake rate=20 level=10]PAIN[/shake][/color] [color=#555555]...... no ......[/color] [color=#ff0000][shake rate=20 level=10]CURE[/shake][/color]",
	
	"[color=#555555]...... sorry ...... your child ......[/color] [color=#ff0000][shake rate=20 level=10]WON'T SURVIVE[/shake][/color]"
]

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var camera: Camera2D = $Camera2D
@onready var dialogue_label: RichTextLabel = $DialogueUI/DialoguePanel/DialogueLabel
@onready var continue_indicator: Label = $DialogueUI/DialoguePanel/ContinueIndicator
@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var mumble_audio: AudioStreamPlayer = $MumbleAudio
@onready var typing_audio: AudioStreamPlayer = $TypingAudio
@onready var swaying_light: PointLight2D = $Background/HospitalAmbience/SwayingLight

# =============================================================================
# STATE VARIABLES
# =============================================================================

## Current line index in dialogue_lines array
var current_line_index: int = 0

## Whether text is currently being typed (typewriter in progress)
var is_typing: bool = false

## Whether the scene is transitioning out (prevents input)
var is_transitioning: bool = false

## Reference to the active typewriter tween (for cancellation)
var typewriter_tween: Tween = null

## Reference to the camera zoom tween
var camera_tween: Tween = null

# =============================================================================
# LIFECYCLE METHODS
# =============================================================================

func _ready() -> void:
	"""Initialize the cutscene when the scene loads."""
	# Ensure the fade overlay starts transparent
	fade_overlay.color = Color(0, 0, 0, 0)
	
	# Hide continue indicator initially
	continue_indicator.visible = false
	
	# Clear any existing text
	dialogue_label.text = ""
	dialogue_label.visible_ratio = 0.0
	
	# Start the camera zoom animation
	
	# Start the light swaying animation
	_start_light_sway()
	
	# Start the ambient mumble audio (plays continuously)
	_start_mumble_audio()
	
	# Brief delay before starting dialogue (let the scene settle)
	await get_tree().create_timer(1.0).timeout
	
	# Begin the dialogue sequence
	_show_dialogue_line()


func _input(event: InputEvent) -> void:
	"""Handle player input for dialogue advancement."""
	# Ignore input during scene transition
	if is_transitioning:
		return
	
	# Check for Space key or ui_accept action
	var is_advance_pressed := false
	
	if event is InputEventKey:
		if event.keycode == KEY_SPACE and event.pressed and not event.echo:
			is_advance_pressed = true
	
	# Also accept ui_accept action (usually Enter/Space)
	if event.is_action_pressed(ADVANCE_ACTION):
		is_advance_pressed = true
	
	if is_advance_pressed:
		_handle_advance_input()

# =============================================================================
# DIALOGUE SYSTEM
# =============================================================================

func _show_dialogue_line() -> void:
	"""Display the current dialogue line with typewriter effect."""
	if current_line_index >= dialogue_lines.size():
		# All dialogue complete, trigger ending
		_start_fade_out()
		return
	
	# Get the current line
	var line := dialogue_lines[current_line_index]
	
	# Set the full text (BBCode) but hide it initially
	dialogue_label.text = line
	dialogue_label.visible_ratio = 0.0
	
	# Hide continue indicator while typing
	continue_indicator.visible = false
	
	# Start typing state
	is_typing = true
	
	# Start typing sound
	if typing_audio.stream and not typing_audio.playing:
		typing_audio.play()
	
	# Calculate duration based on visible characters (not BBCode tags)
	var visible_char_count := _count_visible_characters(line)
	var type_duration := visible_char_count / TYPE_SPEED
	
	# Create typewriter tween
	if typewriter_tween and typewriter_tween.is_valid():
		typewriter_tween.kill()
	
	typewriter_tween = create_tween()
	typewriter_tween.tween_property(dialogue_label, "visible_ratio", 1.0, type_duration)
	typewriter_tween.tween_callback(_on_typing_complete)


func _on_typing_complete() -> void:
	"""Called when the typewriter effect finishes."""
	is_typing = false
	
	# Stop typing sound
	if typing_audio.playing:
		typing_audio.stop()
	
	# Show continue indicator
	continue_indicator.visible = true
	
	# Animate the continue indicator (pulsing effect)
	_pulse_continue_indicator()


func _handle_advance_input() -> void:
	"""Handle Space/Enter input for dialogue advancement."""
	if is_typing:
		# Skip the typewriter effect - show all text immediately
		_skip_typing()
	else:
		# Advance to the next dialogue line
		_advance_dialogue()


func _skip_typing() -> void:
	"""Skip the typewriter effect and show all text immediately."""
	# Kill the typewriter tween
	if typewriter_tween and typewriter_tween.is_valid():
		typewriter_tween.kill()
	
	# Show all text
	dialogue_label.visible_ratio = 1.0
	
	# Complete typing state
	_on_typing_complete()


func _advance_dialogue() -> void:
	"""Move to the next dialogue line."""
	current_line_index += 1
	
	if current_line_index >= dialogue_lines.size():
		# All lines complete, start fade out
		_start_fade_out()
	else:
		# Show the next line
		_show_dialogue_line()

# =============================================================================
# AUDIO SYSTEM
# =============================================================================

func _start_mumble_audio() -> void:
	"""Start playing the mumble audio continuously."""
	if mumble_audio.stream and not mumble_audio.playing:
		mumble_audio.play()


func _stop_mumble_audio() -> void:
	"""Fade out and stop the mumble audio."""
	if mumble_audio.playing:
		# Fade out the audio smoothly
		var audio_tween := create_tween()
		audio_tween.tween_property(mumble_audio, "volume_db", -40.0, 1.0)
		audio_tween.tween_callback(mumble_audio.stop)

# =============================================================================
# CAMERA & VISUAL EFFECTS
# =============================================================================

func _start_camera_zoom() -> void:
	"""Start the slow zoom-in effect on the camera."""
	camera.zoom = ZOOM_START
	
	camera_tween = create_tween()
	camera_tween.set_ease(Tween.EASE_IN_OUT)
	camera_tween.set_trans(Tween.TRANS_SINE)
	camera_tween.tween_property(camera, "zoom", ZOOM_END, ZOOM_DURATION)


func _start_light_sway() -> void:
	"""Create a subtle swaying animation for the overhead light."""
	if not swaying_light:
		return
	
	var original_pos := swaying_light.position
	var sway_tween := create_tween()
	sway_tween.set_loops()  # Infinite loop
	sway_tween.set_ease(Tween.EASE_IN_OUT)
	sway_tween.set_trans(Tween.TRANS_SINE)
	
	# Sway left and right
	sway_tween.tween_property(swaying_light, "position:x", original_pos.x - 20, 2.0)
	sway_tween.tween_property(swaying_light, "position:x", original_pos.x + 20, 4.0)
	sway_tween.tween_property(swaying_light, "position:x", original_pos.x, 2.0)


func _pulse_continue_indicator() -> void:
	"""Create a pulsing animation on the continue indicator."""
	var pulse_tween := create_tween()
	pulse_tween.set_loops()
	pulse_tween.set_ease(Tween.EASE_IN_OUT)
	pulse_tween.set_trans(Tween.TRANS_SINE)
	
	# Pulse the alpha
	pulse_tween.tween_property(continue_indicator, "modulate:a", 0.4, 0.6)
	pulse_tween.tween_property(continue_indicator, "modulate:a", 1.0, 0.6)

# =============================================================================
# SCENE TRANSITION
# =============================================================================

func _start_fade_out() -> void:
	"""Begin the dramatic ending with text animation and fade to black."""
	is_transitioning = true
	
	# Hide continue indicator
	continue_indicator.visible = false
	
	# Stop any ongoing audio
	_stop_mumble_audio()
	if typing_audio.playing:
		typing_audio.stop()
	
	# Hide the green panel background but keep panel in place (at bottom)
	var panel = $DialogueUI/DialoguePanel
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	
	# Show only the impact word, centered within the label
	dialogue_label.text = "[center][color=#ff0000][shake rate=15 level=8]WON'T SURVIVE[/shake][/color][/center]"
	dialogue_label.visible_ratio = 1.0
	
	# Set pivot for scaling from center of panel
	panel.pivot_offset = panel.size / 2
	
	# Calculate target center position
	var viewport_size = get_viewport().get_visible_rect().size
	var target_y = (viewport_size.y / 2) - (panel.size.y / 2)
	var current_y = panel.global_position.y
	
	# Get reference to background/image for fading
	var background = $Background
	var texture_rect = $TextureRect if has_node("TextureRect") else null
	
	# Animate: move text from bottom to center, zoom in, fade background to BLACK
	var anim_tween := create_tween()
	anim_tween.set_parallel(true)
	anim_tween.set_ease(Tween.EASE_OUT)
	anim_tween.set_trans(Tween.TRANS_SINE)
	
	# Move panel from bottom to center (3 seconds)
	anim_tween.tween_property(panel, "global_position:y", target_y, 3.0)
	
	# Scale up text slowly (3 seconds)
	anim_tween.tween_property(panel, "scale", Vector2(2.0, 2.0), 3.0)
	
	# Fade background to BLACK (change color, not just alpha)
	anim_tween.tween_property(background, "color", Color(0, 0, 0, 1), 3.0)
	if texture_rect:
		anim_tween.tween_property(texture_rect, "modulate:a", 0.0, 3.0)
	
	await anim_tween.finished
	
	# Hold for dramatic effect
	await get_tree().create_timer(0.5).timeout
	
	# Fade out the text
	var fade_text := create_tween()
	fade_text.tween_property(panel, "modulate:a", 0.0, 1.5)
	await fade_text.finished
	
	# Fade to black (already black, just ensure overlay is ready)
	var fade_tween := create_tween()
	fade_tween.tween_property(fade_overlay, "color:a", 1.0, FADE_DURATION)
	fade_tween.tween_callback(_change_scene)


func _change_scene() -> void:
	"""Load the next scene after fade completes."""
	# Small delay for dramatic effect
	await get_tree().create_timer(0.5).timeout
	
	# Change to the main game scene
	var error := get_tree().change_scene_to_file(NEXT_SCENE)
	if error != OK:
		push_error("Failed to load scene: " + NEXT_SCENE)

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

func _count_visible_characters(bbcode_text: String) -> int:
	"""
	Count the number of visible characters in a BBCode string.
	Excludes BBCode tags from the count for accurate typing duration.
	"""
	# Simple regex-free approach: remove content within [ ]
	var result := ""
	var in_tag := false
	
	for c in bbcode_text:
		if c == "[":
			in_tag = true
		elif c == "]":
			in_tag = false
		elif not in_tag:
			result += c
	
	return result.length()
