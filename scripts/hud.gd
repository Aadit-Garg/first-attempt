extends CanvasLayer

var infec
@onready var infec_bar: TextureProgressBar = $Infec_bar
@onready var ammo_label: Label = $AmmoContainer/AmmoLabel
@onready var reload_prompt: Label = $ReloadPrompt
@onready var ammo_container: Control = $AmmoContainer
@onready var reload_bar: ProgressBar = $ReloadBar

func _ready() -> void:
	# Find the gun and connect to its signals
	call_deferred("_connect_gun_signals")
	reload_prompt.visible = false
	reload_bar.visible = false

func _connect_gun_signals() -> void:
	# Wait a frame to ensure player is loaded
	await get_tree().process_frame
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var gun = player.get_node_or_null("gun")
		if gun:
			gun.ammo_changed.connect(_on_ammo_changed)
			gun.needs_reload.connect(_on_needs_reload)
			gun.reload_started.connect(_on_reload_started)
			gun.reload_progress.connect(_on_reload_progress)
			gun.reload_finished.connect(_on_reload_finished)
			# Get initial ammo state
			ammo_label.text = str(gun.bullets_in_gun) + "/" + str(gun.spare_bullets)

func _process(delta: float) -> void:
	infec = GameManager.infection_level
	update_infection(infec, 100)

func update_infection(current_in, max_in: int):
	infec_bar.max_value = max_in
	infec_bar.value = current_in

func _on_ammo_changed(bullets_in_gun: int, spare_bullets: int) -> void:
	ammo_label.text = str(bullets_in_gun) + "/" + str(spare_bullets)

func _on_needs_reload(should_show: bool) -> void:
	reload_prompt.visible = should_show

func _on_reload_started(_reload_time: float) -> void:
	reload_bar.visible = true
	reload_bar.value = 0

func _on_reload_progress(progress: float) -> void:
	reload_bar.value = progress * 100

func _on_reload_finished() -> void:
	reload_bar.visible = false
