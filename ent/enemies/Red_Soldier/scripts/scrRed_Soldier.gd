extends CharacterBody2D

# ==============================================================================
# CONSTANTES
# ==============================================================================
const SPEED := 50.0
const ATTACK_DAMAGE := 10
const ATTACK_RANGE := 60.0  # distância para iniciar o ataque
const CHASE_RANGE := 200

# ==============================================================================
# NÓS REFERENCIADOS
# ==============================================================================
@onready var _sprite: AnimatedSprite2D = $ansprRed_Soldier
@onready var _hitbox_col: CollisionShape2D = $aHitbox/colHitbox
@onready var _hitbox: Area2D = $aHitbox

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================
var _direction := -1
var _is_attacking := false
var _player: Node2D = null

# ==============================================================================
# PRONTO
# ==============================================================================
func _ready() -> void:
	_hitbox_col.disabled = false
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.frame_changed.connect(_on_frame_changed)
	_hitbox.body_entered.connect(_on_hitbox_body_entered)

# ==============================================================================
# LOOP PRINCIPAL
# ==============================================================================
func _physics_process(delta: float) -> void:
	_handle_gravity(delta)
	_find_player()
	
	if not _is_attacking:
		_try_attack()
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
	if _player == null:
		if is_on_wall():
			_direction *= -1
		velocity.x = _direction * SPEED
		return
	var distance := global_position.distance_to(_player.global_position)
	if distance <= CHASE_RANGE:
		_direction = 1 if _player.global_position.x > global_position.x else -1
		velocity.x = _direction * SPEED
	else:
		if is_on_wall():
			_direction *= -1
		velocity.x = _direction * SPEED

# ==============================================================================
# DETECÇÃO DO PLAYER
# ==============================================================================
func _find_player() -> void:
	# Busca o player pelo grupo (certifique-se que o player está no grupo "player")
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]

func _try_attack() -> void:
	if _player == null:
		return
	
	var distance := global_position.distance_to(_player.global_position)
	
	if distance <= ATTACK_RANGE:
		# Vira para o lado do player antes de atacar
		_direction = 1 if _player.global_position.x > global_position.x else -1
		start_attack()

# ==============================================================================
# ANIMAÇÕES
# ==============================================================================
func _update_animation() -> void:
	_sprite.flip_h = _direction < 0
	
	if _is_attacking:
		return
	
	if is_on_floor():
		_sprite.play("walk")

# ==============================================================================
# HITBOX - Ativa só nos frames de impacto
# ==============================================================================
func _on_frame_changed() -> void:
	if _sprite.animation == "attack":
		# Frames 2 e 3 são os de impacto — ajuste conforme seu sprite
		_hitbox_col.disabled = _sprite.frame not in [2, 3]

func _on_animation_finished() -> void:
	if _sprite.animation == "attack":
		_is_attacking = false
		_hitbox_col.disabled = true

# ==============================================================================
# ATAQUE
# ==============================================================================
func start_attack() -> void:
	if _is_attacking:
		return
	_is_attacking = true
	velocity.x = 0
	_sprite.play("attack")

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.take_damage(ATTACK_DAMAGE)
