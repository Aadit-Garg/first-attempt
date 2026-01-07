extends Control
## Opening Cutscene: THE PROMISE - Flatline Protocol
## 
## A multi-phase cinematic cutscene featuring:
## - Phase 1: Black screen with narrative text
## - Phase 2: Safehouse scene fade-in
## - Phase 3: Portrait-based dialogue (Dad/Daughter)
## - Phase 4: Objective overlay and gameplay transition

# =============================================================================
# CONFIGURATION
# =============================================================================

const TYPE_SPEED: float = 35.0
const FADE_DURATION := 1.5
const NEXT_SCENE := "res://scenes/game.tscn"

# =============================================================================
# PORTRAIT TEXTURES
# =============================================================================

@export var father_portrait: Texture2D
@export var daughter_portrait: Texture2D

# =============================================================================
# PHASE 1: INTRO TEXT
# =============================================================================

var intro_texts: Array[String] = [
	"They said the Spores take your mind first...",
	"Then your body."
]

# =============================================================================
# PHASE 3: DIALOGUE DATA
# =============================================================================

# Each entry: { "speaker": "Name", "portrait": "dad"/"daughter", "text": "..." }
var dialogue_sequence: Array[Dictionary] = [
	{"speaker": "Dad", "portrait": "dad", "text": "I can't... I can't move anymore. It hurts."},
	{"speaker": "Daughter", "portrait": "daughter", "text": "Get up, Daddy. We're almost there."},
	{"speaker": "Dad", "portrait": "dad", "text": "The soldiers... they're everywhere."},
	{"speaker": "Daughter", "portrait": "daughter", "text": "I know. But you promised. You promised to get me to the Tower."},
	{"speaker": "Dad", "portrait": "dad", "text": "To the safe zone..."},
	{"speaker": "Daughter", "portrait": "daughter", "text": "Yes. The highest point. Where the air is clean. Please, Daddy. Pick me up."}
]

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var black_background: ColorRect = $BlackBackground
@onready var scene_image: TextureRect = $SceneImage
@onready var narrative_text: Label = $DialogueUI/NarrativeText
@onready var portrait_container: Control = $DialogueUI/PortraitContainer
@onready var portrait: TextureRect = $DialogueUI/PortraitContainer/Portrait
@onready var speaker_name: Label = $DialogueUI/PortraitContainer/SpeakerName
@onready var dialogue_text: RichTextLabel = $DialogueUI/PortraitContainer/DialogueText
@onready var continue_indicator: Label = $DialogueUI/PortraitContainer/DialogueBackdrop/ContinueIndicator
@onready var objective_overlay: Control = $DialogueUI/ObjectiveOverlay
@onready var objective_text: Label = $DialogueUI/ObjectiveOverlay/ObjectiveText
@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var ambience_audio: AudioStreamPlayer = $AmbienceAudio
@onready var heartbeat_audio: AudioStreamPlayer = $HeartbeatAudio
@onready var music_audio: AudioStreamPlayer = $MusicAudio
@onready var tinnitus_audio: AudioStreamPlayer = $TinnitusAudio
@onready var typing_audio: AudioStreamPlayer = $TypingAudio

# =============================================================================
# STATE
# =============================================================================

enum Phase { INTRO, SCENE_FADE, DIALOGUE, OBJECTIVE, TRANSITION }
var current_phase: Phase = Phase.INTRO
var current_index: int = 0
var is_typing: bool = false
var is_waiting_for_input: bool = false
var is_transitioning: bool = false
var typewriter_tween: Tween = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Load portrait textures
	father_portrait = load("res://asset/father.png")
	daughter_portrait = load("res://asset/daughter.png")
	
	# Initialize visibility
	narrative_text.text = ""
	narrative_text.modulate.a = 0.0
	scene_image.modulate.a = 0.0
	portrait_container.visible = false
	objective_overlay.visible = false
	fade_overlay.color.a = 0.0
	fade_overlay.visible = true
	
	# Connect audio finished signals for looping
	ambience_audio.finished.connect(_on_ambience_finished)
	heartbeat_audio.finished.connect(_on_heartbeat_finished)
	music_audio.finished.connect(_on_music_finished)
	
	# Start ambience audio (rain + heartbeat for intro atmosphere)
	if ambience_audio.stream:
		ambience_audio.play()
	if heartbeat_audio.stream:
		heartbeat_audio.play()
	
	# Begin cutscene
	await get_tree().create_timer(1.0).timeout
	_run_phase_intro()


# Audio looping callbacks
func _on_ambience_finished() -> void:
	if not is_transitioning:
		ambience_audio.play()

func _on_heartbeat_finished() -> void:
	if not is_transitioning:
		heartbeat_audio.play()

func _on_music_finished() -> void:
	if not is_transitioning:
		music_audio.play()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo):
		_handle_input()

# =============================================================================
# PHASE 1: INTRO (Black Screen + Text)
# =============================================================================

func _run_phase_intro() -> void:
	current_phase = Phase.INTRO
	current_index = 0
	await _show_intro_text()


func _show_intro_text() -> void:
	if current_index >= intro_texts.size():
		# Move to Phase 2
		await get_tree().create_timer(1.0).timeout
		_run_phase_scene_fade()
		return
	
	var text = intro_texts[current_index]
	narrative_text.text = text
	
	# Fade in
	var fade_in = create_tween()
	fade_in.tween_property(narrative_text, "modulate:a", 1.0, 1.0)
	await fade_in.finished
	
	# Hold
	is_waiting_for_input = true


func _advance_intro() -> void:
	is_waiting_for_input = false
	
	# Fade out current text
	var fade_out = create_tween()
	fade_out.tween_property(narrative_text, "modulate:a", 0.0, 0.8)
	await fade_out.finished
	
	current_index += 1
	await _show_intro_text()

# =============================================================================
# PHASE 2: SCENE FADE IN
# =============================================================================

func _run_phase_scene_fade() -> void:
	current_phase = Phase.SCENE_FADE
	narrative_text.visible = false
	
	# Start the sad acoustic guitar music
	if music_audio.stream:
		music_audio.play()
	
	# Fade in the safehouse scene (low contrast - only fade to 0.6)
	var fade_in = create_tween()
	fade_in.tween_property(scene_image, "modulate:a", 0.6, 2.0)
	await fade_in.finished
	
	# Brief pause before dialogue
	await get_tree().create_timer(1.5).timeout
	
	# Start dialogue phase
	_run_phase_dialogue()

# =============================================================================
# PHASE 3: DIALOGUE (Portrait System)
# =============================================================================

func _run_phase_dialogue() -> void:
	current_phase = Phase.DIALOGUE
	current_index = 0
	portrait_container.visible = true
	await _show_dialogue_line()


func _show_dialogue_line() -> void:
	if current_index >= dialogue_sequence.size():
		# Move to Phase 4
		portrait_container.visible = false
		await get_tree().create_timer(0.5).timeout
		_run_phase_objective()
		return
	
	var entry = dialogue_sequence[current_index]
	
	# Set portrait
	if entry.portrait == "dad":
		portrait.texture = father_portrait
	else:
		portrait.texture = daughter_portrait
	
	# Set speaker name
	speaker_name.text = entry.speaker
	
	# Set dialogue text
	dialogue_text.text = entry.text
	dialogue_text.visible_ratio = 0.0
	
	# Hide continue indicator
	continue_indicator.visible = false
	
	# Typewriter effect
	is_typing = true
	var char_count = entry.text.length()
	var duration = char_count / TYPE_SPEED
	
	# Start typing sound
	if typing_audio.stream and not typing_audio.playing:
		typing_audio.play()
	
	if typewriter_tween and typewriter_tween.is_valid():
		typewriter_tween.kill()
	
	typewriter_tween = create_tween()
	typewriter_tween.tween_property(dialogue_text, "visible_ratio", 1.0, duration)
	typewriter_tween.tween_callback(_on_dialogue_typing_complete)


func _on_dialogue_typing_complete() -> void:
	is_typing = false
	
	# Stop typing sound
	if typing_audio.playing:
		typing_audio.stop()
	
	continue_indicator.visible = true
	is_waiting_for_input = true
	_pulse_indicator()


func _advance_dialogue() -> void:
	is_waiting_for_input = false
	continue_indicator.visible = false
	current_index += 1
	await _show_dialogue_line()


func _skip_dialogue_typing() -> void:
	if typewriter_tween and typewriter_tween.is_valid():
		typewriter_tween.kill()
	dialogue_text.visible_ratio = 1.0
	
	# Stop typing sound
	if typing_audio.playing:
		typing_audio.stop()
	
	_on_dialogue_typing_complete()

# =============================================================================
# PHASE 4: OBJECTIVE OVERLAY
# =============================================================================

func _run_phase_objective() -> void:
	current_phase = Phase.OBJECTIVE
	objective_overlay.visible = true
	
	# Play tinnitus sound (high-pitched ringing)
	if tinnitus_audio.stream:
		tinnitus_audio.play()
	
	# Fade in objective text
	var fade_in = create_tween()
	fade_in.tween_property(objective_text, "modulate:a", 1.0, 0.5)
	await fade_in.finished
	
	# Hold for dramatic effect
	await get_tree().create_timer(3.0).timeout
	
	# Transition to gameplay
	_run_phase_transition()

# =============================================================================
# PHASE 5: TRANSITION TO GAMEPLAY
# =============================================================================

func _run_phase_transition() -> void:
	current_phase = Phase.TRANSITION
	
	# Fade out objective
	var fade_obj = create_tween()
	fade_obj.tween_property(objective_text, "modulate:a", 0.0, 1.0)
	await fade_obj.finished
	
	# Fade to black
	var fade_black = create_tween()
	fade_black.tween_property(fade_overlay, "color:a", 1.0, FADE_DURATION)
	await fade_black.finished
	
	# Stop audio
	ambience_audio.stop()
	if music_audio.playing:
		music_audio.stop()
	
	# Load game
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://levels/tutorial_level.tscn")
	GameManager.infection_level=0
# =============================================================================
# INPUT HANDLING
# =============================================================================

func _handle_input() -> void:
	match current_phase:
		Phase.INTRO:
			if is_waiting_for_input:
				_advance_intro()
		Phase.DIALOGUE:
			if is_typing:
				_skip_dialogue_typing()
			elif is_waiting_for_input:
				_advance_dialogue()
		_:
			pass  # No input during other phases

# =============================================================================
# UTILITIES
# =============================================================================

func _pulse_indicator() -> void:
	var pulse = create_tween()
	pulse.set_loops()
	pulse.tween_property(continue_indicator, "modulate:a", 0.4, 0.5)
	pulse.tween_property(continue_indicator, "modulate:a", 1.0, 0.5)
