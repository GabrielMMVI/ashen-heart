extends Node2D

@onready var texto = $ColorRect/TextoNarrativa

var linhas = [
	"Há anos, Siegfried deixou seu lar em busca de glória e batalhas...",
	"Sua jornada o levou por terras distantes — mas seu coração sempre esteve com sua família.",
	"Numa noite fria de acampamento, um mensageiro chegou...",
]

var current_index = 0
var is_typing = false
var type_speed = 0.04

func _ready():
	show_line(current_index)

func show_line(index: int):
	texto.text = ""
	is_typing = true
	for letter in linhas[index]:
		texto.text += letter
		await get_tree().create_timer(type_speed).timeout
	is_typing = false

func _process(_delta):
	if Input.is_action_just_pressed("ui_accept"):
		if is_typing:
			is_typing = false
			texto.text = linhas[current_index]
		else:
			current_index += 1
			if current_index < linhas.size():
				show_line(current_index)
			else:
				get_tree().change_scene_to_file("res://scn/carta_intro.tscn")
