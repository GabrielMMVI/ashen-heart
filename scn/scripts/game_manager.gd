extends Node

# Essa lista vai guardar os IDs das armas coletadas pelo jogador
var saved_unlocked_weapons: Array = [0] # 0 equivale a Weapon.SWORD (sua espada)

# Função para resetar caso o jogador morra ou reinicie o jogo do zero
func reset_game() -> void:
	saved_unlocked_weapons = [0]
