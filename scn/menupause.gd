extends Node2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false

func _on_button_pressed() -> void:
	get_tree().paused = false
	visible = false
	queue_free()

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scn/menuinicial.tscn")


func _on_button_4_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
	
func _on_button_3_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scn/MainMenu.tscn")
