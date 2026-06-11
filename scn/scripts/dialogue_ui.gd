extends CanvasLayer

@onready var dialogue_box = $DialogueBox
@onready var dialogue_text = $DialogueBox/DialogueText
@onready var speaker_name = $DialogueBox/SpeakerName

var dialogues = []
var current_index = 0
var is_typing = false
var type_speed = 0.03

func _ready():
	dialogue_box.visible = false

func start_dialogue(lines: Array):
	dialogues = lines
	current_index = 0
	dialogue_box.visible = true
	show_line(current_index)

func show_line(index: int):
	var line = dialogues[index]
	speaker_name.text = line["name"]
	dialogue_text.text = ""
	is_typing = true
	for letter in line["text"]:
		dialogue_text.text += letter
		await get_tree().create_timer(type_speed).timeout
	is_typing = false

func _process(_delta):
	if not dialogue_box.visible:
		return
	if Input.is_action_just_pressed("ui_accept"):
		if is_typing:
			is_typing = false
			dialogue_text.text = dialogues[current_index]["text"]
		else:
			current_index += 1
			if current_index < dialogues.size():
				show_line(current_index)
			else:
				dialogue_box.visible = false
