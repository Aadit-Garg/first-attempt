extends Node2D

@onready var timer: Timer = $Timer
@onready var text_label: Label = $Label

# Array of text to display in sequence
var dialogue_lines: Array[String] = [
	"WHAT",
	"How Did you reach this place???",
	"Go do some Work mann!!!!!!!!",
	"okay okay i guess you are cool now 
	that you found a bug.",
	"now go and finish the game man!"
]

var current_line_index: int = 0

func called():
	if !timer.autostart:
		timer.start()
	display_next_line()

func _on_timer_timeout():
	# This function is called when the timer reaches 0
	display_next_line()

func display_next_line():
	if current_line_index < dialogue_lines.size():
		# Set the label's text to the current line
		text_label.text = dialogue_lines[current_line_index]
		current_line_index += 1
		# Restart the timer for the next interval
		timer.start()
	else:
		# Stop the timer and handle the end of the dialogue
		timer.stop()
		print("Dialogue finished!")
