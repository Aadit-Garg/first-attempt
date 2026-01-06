extends Node
var infection_level=1
var rate=0
var decrease=15

@onready var glitch_rect: ColorRect  = $"../canvas/CanvasLayer/ColorRect"
@onready var timer: Timer = $Timer
@onready var player: CharacterBody2D = $"../player"

func _process(delta: float) -> void:
	#rate of infection
	if infection_level !=100:
		infection_level += delta * rate 
		infection_level = clamp(infection_level, 0.0, 100.0)
		#print(infection_level)
		#state for infection level
		if infection_level>=50 && infection_level!=100:
			glitch_rect.material.set_shader_parameter("infection_level", infection_level)
		#if infection_level==100:
			#infection_level=0
			#print("YOU DIED!!!")
			#timer.start()
	else:
		timer.start()
		infection_level=0
		glitch_rect.material.set_shader_parameter("infection_level", 0)
		print("YOU DIED!!!")
		player.queue_free()
		#Engine.time_scale=0.5
		
#how it will work for health items
func reduce_infection():
	infection_level-=decrease
	infection_level=clamp(infection_level,0,100)


func _on_timer_timeout() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")
