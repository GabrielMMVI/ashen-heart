extends Area2D

@onready var dialogue_ui = get_node("/root/InteriorCasa/DialogueUI")

var triggered = false

var dialogues = [
	{"name": "Estranho", "text": "Ei, você aí! Pare onde está!"},
	{"name": "Arthur", "text": "Pai? Lyra? Onde estão vocês?"},
	{"name": "Estranho", "text": "Eles não podem te ajudar agora..."},
	{"name": "Arthur", "text": "O que você fez com eles?!"},
]

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	print("Corpo entrou: ", body.name)
	if body.is_in_group("player") and not triggered:
		print("Player detectado!")
		triggered = true
		dialogue_ui.start_dialogue(dialogues)
