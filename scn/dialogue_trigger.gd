extends Area2D

@onready var dialogue_ui = get_node("/root/Node2D/DialogueUI")

var triggered = false

var dialogues = [
	{"name": "Arthur", "text": "Maria! O que aconteceu aqui?!"},
	{"name": "Maria", "text": "Senhor Arthur... ainda bem que chegou."},
	{"name": "Maria", "text": "Seu pai... ele tentou protegê-la."},
	{"name": "Arthur", "text": "Protegê-la? Onde está Brunhilda?!"},
	{"name": "Maria", "text": "Homens armados vieram durante a noite..."},
	{"name": "Maria", "text": "...levaram a senhora Brunhilda à força."},
	{"name": "Arthur", "text": "Para onde?!"},
	{"name": "Maria", "text": "Ouvi eles falarem em um castelo ao norte..."},
	{"name": "Maria", "text": "...mas senhor, é muito perigoso."},
	{"name": "Arthur", "text": "Não me importa. Vou trazê-la de volta."},
]

func _ready():
	body_entered.connect(_on_body_entered)
	var player = get_node("/root/Node2D/chbPlayer")
	for child in player.get_children():
		if child is Camera2D:
			child.enabled = false

func _on_body_entered(body):
	print("Corpo entrou: ", body.name)
	if body.is_in_group("player") and not triggered:
		print("Player detectado!")
		triggered = true
		dialogue_ui.start_dialogue(dialogues)
