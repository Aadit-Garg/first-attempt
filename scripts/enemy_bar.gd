extends TextureProgressBar

var health: int = 100
func _ready() -> void:
	health = 100
func _process(delta: float) -> void:
	update_health(health,0)

func update_health(current_in: int, min_in: int):
	min_value = min_in
	value = current_in
