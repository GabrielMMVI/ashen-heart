extends CanvasLayer

var pause_scene := preload("res://scn/menupause.tscn")
var pause_menu: Node = null
#Adiciona a referencia para a barra de vida
@onready var weapon_label: Label = $MarginContainer/VBoxContainer/WeaponLabel
@onready var health_bar: TextureProgressBar = $TextureProgressBar2

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.weapon_changed.connect(_on_player_weapon_changed)
		player.health_changed.connect(_on_player_health_changed)
	else:
		push_error("Player não encontrado pela HUD! Verifique se ele está no grupo 'player'.")

func _create_pause_menu() -> void:
	if pause_menu == null:
		pause_menu = pause_scene.instantiate()
		get_tree().current_scene.add_child(pause_menu)
		pause_menu.visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_create_pause_menu()

		var pausing := !get_tree().paused
		pause_menu.visible = pausing
		get_tree().paused = pausing

		get_viewport().set_input_as_handled()

func _on_player_weapon_changed(weapon_name: String) -> void:
	weapon_label.text = "Arma: " + weapon_name

func _on_player_health_changed(current: int, max_val: int) -> void:
	health_bar.max_value = max_val
	health_bar.value = current
