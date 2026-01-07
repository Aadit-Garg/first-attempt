extends Node
var infection_level=1
var rate=0
var decrease=10
@onready var glitch_rect: Control = $canvas
@onready var timer: Timer = $Timer
@onready var player: CharacterBody2D = $"../player"

func _process(delta: float) -> void:
	#rate of infection
	infection_level += delta * rate 
	infection_level = clamp(infection_level, 0.0, 100.0)
		
#how it will work for health items
func reduce_infection():
	infection_level-=decrease
	infection_level=clamp(infection_level,0,100)
