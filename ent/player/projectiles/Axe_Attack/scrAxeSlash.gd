extends Area2D

# ==============================================================================
# CONSTANTES E NÓS
# ==============================================================================
const DAMAGE := 70
# Coloque aqui o nome correto do nó de animação do seu corte de espada
@onready var _sprite: AnimatedSprite2D = $ansprAxeSlash 

# ==============================================================================
# PRONTO
# ==============================================================================
func _ready() -> void:
	area_entered.connect(_on_area_entered)
	
	# O nó inteiro se destrói (queue_free) automaticamente quando a animação de corte acabar
	_sprite.play("attack_axe")
	_sprite.animation_finished.connect(queue_free)

# ==============================================================================
# INICIALIZAÇÃO DO GOLPE
# ==============================================================================
func swing(facing_right: bool) -> void:
	# Ajusta a distância (offset) para a espada aparecer na frente do player e não dentro dele
	var offset_x = 0.0 if facing_right else 0.0
	position = Vector2(offset_x, 0)
	
	# Espelha o sprite da espada para bater pro lado certo
	_sprite.flip_h = not facing_right

# ==============================================================================
# DETECÇÃO DE COLISÃO
# ==============================================================================
func _on_area_entered(area: Area2D) -> void:
	# Procuramos a Hurtbox do inimigo
	if area.is_in_group("enemy_hurtbox"):
		var enemy = area.get_parent()
		if enemy.has_method("take_damage"):
			enemy.take_damage(DAMAGE)
