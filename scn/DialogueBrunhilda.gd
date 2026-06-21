extends Area2D

@onready var dialogue_ui = get_node("/root/QuartoBrunhilda/DialogueUI")

var triggered = false

var dialogues = [
	{"name": "Arthur", "text": "Brunhilda?!"},
	{"name": "Brunhilda", "text": "Arthur... você veio."},
	{"name": "Arthur", "text": "Eu nunca pararia de te procurar."},
	{"name": "Brunhilda", "text": "Eu sabia que viria."},
]

func _ready():
	body_entered.connect(_on_body_entered)
	dialogue_ui.dialogue_finished.connect(_on_dialogue_finished)
	var player = get_node("/root/QuartoBrunhilda/chbPlayer")
	for child in player.get_children():
		if child is Camera2D:
			child.enabled = false

func _on_dialogue_finished():
	get_tree().change_scene_to_file("res://scn/tela_final.tscn")

func _on_body_entered(body):
	if body.is_in_group("player") and not triggered:
		triggered = true
		dialogue_ui.start_dialogue(dialogues)
