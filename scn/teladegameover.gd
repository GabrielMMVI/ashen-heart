extends Node2D

func _ready():
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func _on_button_tentar_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scn/Game.tscn")

func _on_button_sair_over_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scn/MainMenu.tscn")
