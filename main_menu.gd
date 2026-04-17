extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
func _on_button_pressed():
	get_tree().change_scene_to_file("res://Game.tscn")

func _on_button_2_pressed():
	get_tree().quit()
