extends Node2D

@onready var check: StaticBody2D = $check
@onready var item_gun: Area2D = $item_gun
@onready var death_screen: ColorRect = $CanvasLayer/death_screen

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	death_screen.visible=false
	GameManager.gun_found=false
	GameManager.shooting=false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_item_gun_body_entered(body: Node2D) -> void:
	GameManager.gun_found=true
	GameManager.shooting=true
	check.queue_free()
	item_gun.queue_free()
