extends CharacterBody2D

# ==============================================================================
# CONSTANTES
# ==============================================================================
# Reduzi a velocidade. 300.0 é muito rápido para uma patrulha padrão de inimigo.
const SPEED := 50.0 

# ==============================================================================
# NÓS REFERENCIADOS
# ==============================================================================
# Assumi o nome 'ansprEnemy' seguindo a convenção usada no seu Player.
# Ajuste se o nome do nó no seu cenário for diferente.
@onready var _sprite: AnimatedSprite2D = $ansprRed_Soldier

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================
var _direction := -1 # Começa andando para a esquerda (padrão de muitos jogos)

# ==============================================================================
# VARIÁVEL DE DANO
# ==============================================================================

# ==============================================================================
# LOOP PRINCIPAL
# ==============================================================================
func _physics_process(delta: float) -> void:
	_handle_gravity(delta)
	_handle_movement()
	_update_animation()
	move_and_slide()

# ==============================================================================
# FÍSICA E MOVIMENTO
# ==============================================================================
func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

func _handle_movement() -> void:
	# Bateu na parede? Inverte a direção.
	if is_on_wall():
		_direction *= -1
		
	velocity.x = _direction * SPEED

# ==============================================================================
# ANIMAÇÕES
# ==============================================================================
func _update_animation() -> void:
	# Atualiza a direção visual (assume que o sprite original olha para a direita)
	_sprite.flip_h = _direction < 0
	
	if is_on_floor():
		_sprite.play("walk")
