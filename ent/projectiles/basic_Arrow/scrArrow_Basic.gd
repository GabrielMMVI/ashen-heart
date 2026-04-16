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
# Pega a gravidade padrão configurada no projeto (Project Settings)
var custom_gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# ==============================================================================
# PRONTO
# ==============================================================================
func _ready() -> void:
	# Conecta o sinal de colisão nativo do Area2D
	body_entered.connect(_on_body_entered)
	
	# Opcional: Destrói a flecha após 5 segundos para não lotar a memória da cena
	var timer := get_tree().create_timer(5.0)
	timer.timeout.connect(queue_free)

# ==============================================================================
# FUNÇÃO CHAMADA PELO INIMIGO
# ==============================================================================
# Agora recebe o vetor calculado (X e Y perfeitos) pelo atirador
func fire(start_velocity: Vector2) -> void:
	velocity = start_velocity

# ==============================================================================
# FÍSICA E MOVIMENTO DA FLECHA
# ==============================================================================
func _physics_process(delta: float) -> void:
	if is_stuck:
		return # Se cravou em algo, para de processar movimento
	
	# Aplica gravidade
	velocity.y += custom_gravity * delta
	
	# Move a flecha manualmente (pois é um Area2D)
	global_position += velocity * delta
	
	# Faz a flecha "apontar" visualmente para a direção em que está caindo
	rotation = velocity.angle()

# ==============================================================================
# DETECÇÃO DE COLISÃO
# ==============================================================================
func _on_body_entered(body: Node2D) -> void:
	if is_stuck:
		return
		
	if body.is_in_group("player"):
		# Se acertou o player, dá dano e destrói a flecha
		if body.has_method("take_damage"):
			body.take_damage(DAMAGE)
		queue_free()
	else:
		# Se não é o player, assumimos que é o chão/parede (TileMap ou StaticBody)
		# A flecha para de se mover e fica grudada
		is_stuck = true
