extends Area2D

# ==============================================================================
# VARIÁVEIS E CONSTANTES
# ==============================================================================
var velocity := Vector2.ZERO
var is_stuck := false
var custom_gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
const DAMAGE := 30

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
func fire(start_velocity: Vector2) -> void:
	velocity = start_velocity

# ==============================================================================
# FÍSICA E MOVIMENTO DA FLECHA
# ==============================================================================
func _physics_process(delta: float) -> void:
	if is_stuck:
		return

	velocity.y += custom_gravity * delta
	global_position += velocity * delta
	rotation = velocity.angle()

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
			enemy.take_damage(DAMAGE)
		queue_free()
