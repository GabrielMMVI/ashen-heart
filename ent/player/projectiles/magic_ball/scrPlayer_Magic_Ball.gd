extends Area2D

# ==============================================================================
# VARIÁVEIS E CONSTANTES
# ==============================================================================
var velocity := Vector2.ZERO
const SPEED := 100
const DAMAGE := 15
const KNOCKBACK_FORCE := Vector2(50.0, 10.0)


# ==============================================================================
# PRONTO
# ==============================================================================
func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	var timer := get_tree().create_timer(5.0)
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
	# Padronizado para procurar especificamente a Hurtbox do Inimigo
	if area.is_in_group("enemy_hurtbox"):
		var enemy = area.get_parent()
		if enemy.has_method("take_damage"):
			var dir_x = sign(velocity.x)
			if dir_x == 0: dir_x = 1 # Prevenção caso caia 100% reta
			
			var applied_force = Vector2(KNOCKBACK_FORCE.x * dir_x, KNOCKBACK_FORCE.y)
			enemy.take_damage(DAMAGE, applied_force)
		queue_free()
