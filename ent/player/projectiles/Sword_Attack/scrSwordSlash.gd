extends Area2D

# ==============================================================================
# CONSTANTES E NÓS
# ==============================================================================
const DAMAGE := 30
const KNOCKBACK_FORCE := Vector2(100.0, -25.0)

var _is_facing_right := true
# Coloque aqui o nome correto do nó de animação do seu corte de espada
@onready var _sprite: AnimatedSprite2D = $ansprSwordSlash 

# ==============================================================================
# PRONTO
# ==============================================================================
func _ready() -> void:
	area_entered.connect(_on_area_entered)
	
	# O nó inteiro se destrói (queue_free) automaticamente quando a animação de corte acabar
	_sprite.play("attack")
	_sprite.animation_finished.connect(queue_free)

# ==============================================================================
# INICIALIZAÇÃO DO GOLPE
# ==============================================================================
func swing(facing_right: bool) -> void:
	_is_facing_right = facing_right
	var offset_x = 15.0 if facing_right else -15.0
	position = Vector2(offset_x, 0)
	
	_sprite.flip_h = not facing_right

# ==============================================================================
# DETECÇÃO DE COLISÃO
# ==============================================================================
func _on_area_entered(area: Area2D) -> void:
	# Procuramos a Hurtbox do inimigo
	if area.is_in_group("enemy_hurtbox"):
		var enemy = area.get_parent()
		if enemy.has_method("take_damage"):
			var dir_x = 1 if _is_facing_right else -1
			var applied_force = Vector2(KNOCKBACK_FORCE.x * dir_x, KNOCKBACK_FORCE.y)
			
			enemy.take_damage(DAMAGE, applied_force)
