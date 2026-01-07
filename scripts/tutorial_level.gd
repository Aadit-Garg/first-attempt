extends Node2D
@onready var light = $player/character_light
@onready var light2 = $player/PointLight2D
@onready var canvas: Control = $canvas
@onready var glitch_rect = $canvas/CanvasLayer/ColorRect
@onready var item: Area2D = $item
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	light.visible=false
	light2.visible=false
	GameManager.rate=0
	canvas.visible=false


func _on_item_body_entered(body: Node2D) -> void:
	glitch_rect.material.set_shader_parameter("infection_level", 0)
	item.queue_free()


func _on_exit_body_entered(body: Node2D) -> void:
	get_tree().change_scene_to_file("res://levels/level_1.tscn")
