extends CanvasLayer

@onready var weapon_label: Label = $MarginContainer/VBoxContainer/WeaponLabel
# Adiciona a referência para a barra de vida
@onready var health_bar: TextureProgressBar = $TextureProgressBar2

func _ready() -> void:
	var player = get_tree().get_first_node_in_group("player")
	
	if player:
		player.weapon_changed.connect(_on_player_weapon_changed)
		# Conecta o novo sinal de vida
		player.health_changed.connect(_on_player_health_changed)
	else:
		push_error("Player não encontrado pela HUD! Verifique se ele está no grupo 'player'.")

func _on_player_weapon_changed(weapon_name: String) -> void:
	weapon_label.text = "Arma: " + weapon_name

# Função que atualiza a ProgressBar quando o player toma dano (ou cura)
func _on_player_health_changed(current: int, max_val: int) -> void:
	health_bar.max_value = max_val
	health_bar.value = current
