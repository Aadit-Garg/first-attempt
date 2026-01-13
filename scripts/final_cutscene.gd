extends Control

const IMAGE_1_PATH = "res://asset/65f565ee-be93-4bfc-afbf-bca7d9ea53e3_0.jpg"
const IMAGE_2_PATH = "res://asset/84eaa892-3079-4780-89ab-d5609342ec0d_0.jpg"
const DAUGHTER_PATH = "res://asset/daughter.png"
const FATHER_PATH = "res://asset/father.png"
const MUSIC_PATH = "res://asset/Sounds/music-guitar.mp3"
const TYPING_SOUND_PATH = "res://asset/Sounds/bllrr-text-loop-82399.mp3"
const MENU_SCENE = "res://scenes/mainmenu.tscn"

const FADE_DURATION := 2.0
const CROSSFADE_DURATION := 3.0
const TYPEWRITER_SPEED := 0.05
const TEXT_DISPLAY_TIME := 3.0
const FINAL_FADE_DURATION := 3.0
const DARKNESS_WAIT := 1.0

@onready var background: ColorRect = $Background
@onready var image_rect: TextureRect = $ImageRect
@onready var image_rect_2: TextureRect = $ImageRect2
@onready var dialogue_box: PanelContainer = $DialogueBox
@onready var daughter_sprite: TextureRect = $DialogueBox/HBoxContainer/DaughterSprite
@onready var father_sprite: TextureRect = $FatherSprite
@onready var text_label: RichTextLabel = $DialogueBox/HBoxContainer/TextLabel
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var typing_audio: AudioStreamPlayer = $TypingAudio

var current_tween: Tween = null
var typing_tween: Tween = null
var is_typing := false
var skip_requested := false
var waiting_for_text := false


func _ready() -> void:
	_setup_initial_state()
	_run_cutscene()


func _setup_initial_state() -> void:
	background.color = Color.BLACK
	image_rect.modulate.a = 0.0
	image_rect_2.modulate.a = 0.0
	daughter_sprite.modulate.a = 0.0
	father_sprite.modulate.a = 0.0
	daughter_sprite.modulate = Color(1.0, 0.5, 0.5, 0.0)
	text_label.text = ""
	text_label.visible_ratio = 0.0
	
	if ResourceLoader.exists(MUSIC_PATH):
		music_player.stream = load(MUSIC_PATH)
		music_player.finished.connect(_on_music_finished)
		music_player.play()
	
	if ResourceLoader.exists(TYPING_SOUND_PATH):
		typing_audio.stream = load(TYPING_SOUND_PATH)


func _on_music_finished() -> void:
	music_player.play()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if is_typing:
			skip_requested = true
		elif waiting_for_text:
			skip_requested = true


func _run_cutscene() -> void:
	if ResourceLoader.exists(IMAGE_1_PATH):
		image_rect.texture = load(IMAGE_1_PATH)
	
	await _fade_in(image_rect, FADE_DURATION)
	_fade_in_sprite(daughter_sprite, 1.5, 0.7)
	await get_tree().create_timer(1.0).timeout
	
	await _typewriter_text("I told myself it was for her...")
	await _wait_skippable(TEXT_DISPLAY_TIME)
	await _fade_text_out()
	
	await _typewriter_text("That I was doing this to save my little girl.")
	await _wait_skippable(TEXT_DISPLAY_TIME)
	await _fade_text_out()
	
	if ResourceLoader.exists(IMAGE_2_PATH):
		image_rect_2.texture = load(IMAGE_2_PATH)
	
	await _crossfade(image_rect, image_rect_2, CROSSFADE_DURATION)
	_fade_out_sprite(daughter_sprite, 2.0)
	
	await _typewriter_text("But it was never me.")
	await _wait_skippable(2.5)
	await _fade_text_out()
	
	await _typewriter_text("The spores... they were in my brain.")
	await _wait_skippable(TEXT_DISPLAY_TIME)
	await _fade_text_out()
	
	await _typewriter_text("Whispering. Guiding. Compelling.")
	await _wait_skippable(TEXT_DISPLAY_TIME)
	await _fade_text_out()
	
	await _typewriter_text("They led me here... to the highest point in town.")
	await _wait_skippable(TEXT_DISPLAY_TIME)
	await _fade_text_out()
	
	await _typewriter_text("And I released them all.")
	await _wait_skippable(4.0)
	await _fade_text_out()
	
	var end_tween = create_tween()
	end_tween.set_parallel(true)
	end_tween.tween_property(image_rect_2, "modulate:a", 0.0, FINAL_FADE_DURATION)
	end_tween.tween_property(music_player, "volume_db", -40.0, FINAL_FADE_DURATION)
	current_tween = end_tween
	await end_tween.finished
	
	music_player.stop()
	await _wait_skippable(DARKNESS_WAIT)
	
	await _typewriter_text("The town never stood a chance.")
	await _wait_skippable(3.0)
	await _fade_text_out()
	
	await _wait_skippable(1.0)
	get_tree().change_scene_to_file(MENU_SCENE)


func _fade_in(node: CanvasItem, duration: float) -> void:
	current_tween = create_tween()
	current_tween.tween_property(node, "modulate:a", 1.0, duration)
	await current_tween.finished


func _fade_out(node: CanvasItem, duration: float) -> void:
	current_tween = create_tween()
	current_tween.tween_property(node, "modulate:a", 0.0, duration)
	await current_tween.finished


func _fade_in_sprite(node: CanvasItem, duration: float, target_alpha: float = 1.0) -> void:
	var tween = create_tween()
	tween.tween_property(node, "modulate:a", target_alpha, duration)


func _fade_out_sprite(node: CanvasItem, duration: float) -> void:
	var tween = create_tween()
	tween.tween_property(node, "modulate:a", 0.0, duration)


func _crossfade(from_node: CanvasItem, to_node: CanvasItem, duration: float) -> void:
	current_tween = create_tween()
	current_tween.set_parallel(true)
	current_tween.tween_property(from_node, "modulate:a", 0.0, duration)
	current_tween.tween_property(to_node, "modulate:a", 1.0, duration)
	await current_tween.finished


func _typewriter_text(text: String) -> void:
	text_label.text = text
	text_label.visible_ratio = 0.0
	skip_requested = false
	
	is_typing = true
	typing_audio.play()
	
	var total_duration = text.length() * TYPEWRITER_SPEED
	var elapsed := 0.0
	
	while elapsed < total_duration and not skip_requested:
		elapsed += get_process_delta_time()
		text_label.visible_ratio = min(elapsed / total_duration, 1.0)
		await get_tree().process_frame
	
	text_label.visible_ratio = 1.0
	is_typing = false
	typing_audio.stop()
	skip_requested = false


func _wait_skippable(duration: float) -> void:
	waiting_for_text = true
	skip_requested = false
	var elapsed := 0.0
	
	while elapsed < duration and not skip_requested:
		elapsed += get_process_delta_time()
		await get_tree().process_frame
	
	waiting_for_text = false
	skip_requested = false


func _fade_text_out() -> void:
	var tween = create_tween()
	tween.tween_property(text_label, "modulate:a", 0.0, 0.5)
	await tween.finished
	text_label.modulate.a = 1.0
	text_label.text = ""
