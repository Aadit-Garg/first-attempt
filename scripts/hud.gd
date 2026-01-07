extends CanvasLayer
var infec
@onready var infec_bar: TextureProgressBar = $Infec_bar

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	infec=GameManager.infection_level
	update_infection(infec,100)
	
func update_infection(current_in, max_in:int):
	infec_bar.max_value = max_in # Ensures bar scales if max HP changes
	infec_bar.value = current_in
