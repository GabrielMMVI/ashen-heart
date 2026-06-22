extends Area2D

# ==============================================================================
# EXPORTS
# ==============================================================================
# Raio de dano da explosão em pixels — ajuste para corresponder ao visual da cena
@export var blast_radius: float = 60.0

# ==============================================================================
# NÓS REFERENCIADOS
# ==============================================================================
@onready var _sprite: AnimatedSprite2D = $ansprExplosion

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================
var _damage: int = 0

# ==============================================================================
# PRONTO
# ==============================================================================
func _ready() -> void:
	# Quando a animação terminar, some da cena automaticamente
	_sprite.animation_finished.connect(queue_free)

# ==============================================================================
# ATIVAÇÃO — chamada pelo boss imediatamente após instanciar e posicionar
# ==============================================================================
func detonate(damage: int) -> void:
	_damage = damage
	_sprite.play("default")

	# Aguarda um frame para garantir que a posição global já foi aplicada
	await get_tree().process_frame
	_apply_damage()

# ==============================================================================
# DANO — checa por distância diretamente no grupo "player"
# Não depende de collision layers/masks, apenas da posição da explosão.
# ==============================================================================
func _apply_damage() -> void:
	var players := get_tree().get_nodes_in_group("player")
	for player: Node2D in players:
		if global_position.distance_to(player.global_position) <= blast_radius:
			if player.has_method("take_damage"):
				player.take_damage(_damage)
			return   # Dano aplicado uma única vez
