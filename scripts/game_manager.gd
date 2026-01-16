extends Node
@onready var glitch_rect: Control = $canvas
@onready var timer: Timer = $Timer
var infection_level=1
var rate=0
var decrease=10
var bullets_in_gun: int = -1
var spare_bullets: int = -1
var shooting=false
var gun_found=false
var checkpoint_bullets_in_gun: int = -1
var checkpoint_spare_bullets: int = -1
var key_found=false
var went_lv3_2=false

func reset_ammo() -> void:
	bullets_in_gun = -1
	spare_bullets = -1

func _process(delta: float) -> void:
	#rate of infection
	infection_level += delta * rate 
	infection_level = clamp(infection_level, 0.0, 100.0)

#how it will work for health items
func reduce_infection():
	infection_level-=decrease
	infection_level=clamp(infection_level,0,100)

#ammo on restart 
func save_ammo_checkpoint() -> void:
	checkpoint_bullets_in_gun = bullets_in_gun
	checkpoint_spare_bullets = spare_bullets

func restore_ammo_checkpoint() -> void:
	bullets_in_gun = checkpoint_bullets_in_gun
	spare_bullets = checkpoint_spare_bullets
