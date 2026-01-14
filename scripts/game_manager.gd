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

func reset_ammo() -> void:
	bullets_in_gun = -1
	spare_bullets = -1

func _ready():
	pass
	#var player = get_tree().get_first_node_in_group("player")
	#if !gun_found && player:
			##var hud_scene = get_tree().get_current_scene().get_node("HUD")
			#var gun=player.get_node("gun")
			#gun.visible=false
			#if hud_scene:
				#var ammo_hud=hud_scene.get_node("AmmoContainer")
				#ammo_hud.visible=false
func _process(delta: float) -> void:
	#var player = get_tree().get_first_node_in_group("player")
	##gun
	#if !gun_found && player:
		##var hud_scene = get_tree().get_current_scene().get_node("HUD")
		#var gun=player.get_node("gun")
		#gun.visible=false
		##if hud_scene:
			##var ammo_hud=hud_scene.get_node("AmmoContainer")
			##ammo_hud.visible=false
			##print("lulu")
	#rate of infection
	infection_level += delta * rate 
	infection_level = clamp(infection_level, 0.0, 100.0)

#how it will work for health items
func reduce_infection():
	infection_level-=decrease
	infection_level=clamp(infection_level,0,100)
