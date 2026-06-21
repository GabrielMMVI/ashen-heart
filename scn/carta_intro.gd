extends Node2D

@onready var carta_sprite = $Sprite2D

func _ready():
	carta_sprite.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(carta_sprite, "modulate:a", 1.0, 1.5)

func _process(_delta):
	if Input.is_action_just_pressed("ui_accept"):
		get_tree().change_scene_to_file("res://scn/Game.tscn")
