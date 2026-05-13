extends Area2D
# ==============================================================================
# CONSTANTES
# ==============================================================================
const DAMAGE := 10
# ==============================================================================
# VARIÁVEIS
# ==============================================================================
var velocity := Vector2.ZERO
var is_stuck := false
var custom_gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
# ==============================================================================
# PRONTO
# ==============================================================================
func _ready() -> void:
	# Detecta outras Areas (como o aHitbox do player)
	area_entered.connect(_on_area_entered)
	# Detecta corpos físicos (chão, paredes, TileMap)
	body_entered.connect(_on_body_entered)
	
	var timer := get_tree().create_timer(5.0)
	timer.timeout.connect(queue_free)
# ==============================================================================
# FUNÇÃO CHAMADA PELO INIMIGO
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
# DETECÇÃO DE COLISÃO COM O PLAYER (aHitbox)
# ==============================================================================
func _on_area_entered(area: Area2D) -> void:
	if is_stuck:
		return

	# Detecta o aHitbox do player pelo grupo
	if area.is_in_group("player_hurtbox"):
		var player = area.get_parent()
		if player.has_method("take_damage"):
			player.take_damage(DAMAGE)
		queue_free()
# ==============================================================================
# DETECÇÃO DE COLISÃO COM CHÃO E PAREDES
# ==============================================================================
func _on_body_entered(body: Node2D) -> void:
	if is_stuck:
		return

	# Ignora o player (ele é detectado pelo area_entered)
	if body.is_in_group("player"):
		return

	# Chão ou parede — flecha crava
	is_stuck = true
