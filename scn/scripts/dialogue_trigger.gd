extends Area2D

@onready var dialogue_ui = get_node("/root/InteriorCasa/DialogueUI")

var triggered = false

var dialogues = [
	{"name": "Arthur", "text": "Pai !!! Brunhilda !!! Onde estão vocês ?!"},
	{"name": "Voz Misteriosa", "text": "Eles não estão aqui senhor..."},
	{"name": "Voz Misteriosa", "text": "...quero dizer..."},
	{"name": "Voz Misteriosa", "text": "...não sua esposa."},
	{"name": "Arthur", "text": "Quem está aí ?!"},
	{"name": "Voz Misteriosa", "text": "Aqui fora senhor."},
]

func _ready():
	body_entered.connect(_on_body_entered)
	# Desativa a câmera do player nessa cena
	var player = get_node("/root/InteriorCasa/chbPlayer")
	for child in player.get_children():
		if child is Camera2D:
			child.enabled = false

func _on_body_entered(body):
	print("Corpo entrou: ", body.name)
	if body.is_in_group("player") and not triggered:
		print("Player detectado!")
		triggered = true
		dialogue_ui.start_dialogue(dialogues)
