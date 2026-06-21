extends Node2D

func _ready():
	$FecharJogo.pressed.connect(_on_fechar_pressed)
	$Menu.pressed.connect(_on_menu_pressed)

func _on_fechar_pressed():
	get_tree().quit()

func _on_menu_pressed():
	get_tree().change_scene_to_file("res://scn/MainMenu.tscn")
