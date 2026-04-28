extends Area2D

# ==============================================================================
# CONSTANTES
# ==============================================================================
const DAMAGE := 15.0
const SPEED := 60

# ==============================================================================
# VARIÁVEIS
# ==============================================================================
var velocity := Vector2.ZERO

# ==============================================================================
# PRONTO
# ==============================================================================
func _ready() -> void:
	# Detecta outras Areas (como o aHitbox do player)
	area_entered.connect(_on_area_entered)
	# Detecta corpos físicos (chão, paredes, TileMap)
	body_entered.connect(_on_body_entered)
	
	# Destrói a magia após 5 segundos caso ela voe para fora do mapa
	var timer := get_tree().create_timer(5.0)
	timer.timeout.connect(queue_free)

# ==============================================================================
# FUNÇÃO CHAMADA PELO MAGO
# ==============================================================================
func fire(direction: Vector2) -> void:
	velocity = direction * SPEED
	
	# (Opcional) Faz o sprite rotacionar para apontar na direção do voo
	rotation = velocity.angle()
	print("ENEMYFIRE")

# ==============================================================================
# FÍSICA E MOVIMENTO (Sem Gravidade)
# ==============================================================================
func _physics_process(delta: float) -> void:
	# Como não há gravidade, apenas movemos a área na direção constante
	global_position += velocity * delta


# ==============================================================================
# DETECÇÃO DE COLISÃO
# ==============================================================================
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		# Não colide consigo mesmo
		return
	else:
		queue_free()
# ==============================================================================
# DETECÇÃO DE COLISÃO COM O PLAYER (aHitbox)
# ==============================================================================
func _on_area_entered(area: Area2D) -> void:
		# Detecta o aHurtbox do player pelo grupo
	if area.is_in_group("player"):
		var player = area.get_parent()
		if player.has_method("take_damage"):
			player.take_damage(DAMAGE)
			print("Tomou dano")
		queue_free()
