extends Area2D

# ==============================================================================
# VARIÁVEIS E CONSTANTES
# ==============================================================================
var velocity := Vector2.ZERO
const SPEED := 60.0
const DAMAGE := 15


# ==============================================================================
# PRONTO
# ==============================================================================
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	# Prevenção de vazamento de memória (destrói se voar para fora do mapa)
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(queue_free)

# ==============================================================================
# INICIALIZAÇÃO DO MOVIMENTO
# ==============================================================================
func fire(direction: Vector2) -> void:
	# A bolinha tem a própria velocidade
	velocity = direction * SPEED
	rotation = velocity.angle()
	print("PLAYERFIRE")

# ==============================================================================
# FÍSICA E MOVIMENTO (Sem Gravidade)
# ==============================================================================
func _physics_process(delta: float) -> void:
	global_position += velocity * delta

# ==============================================================================
# DETECÇÃO DE COLISÃO
# ==============================================================================
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Não colide consigo mesmo
		return
	else:
		queue_free()
	# ==============================================================================
# DETECÇÃO DE COLISÃO COM O INIMIGO (aHurtbox)
# ==============================================================================
func _on_area_entered(area: Area2D) -> void:
		# Detecta o aHitbox do inimigo pelo grupo
	if area.is_in_group("enemy"):
		var enemy = area.get_parent()
		if enemy.has_method("take_damage"):
			enemy.take_damage(DAMAGE)
			print("Tomou dano")
		queue_free()
	elif area.is_in_group("player"):
		return
	
