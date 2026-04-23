extends CharacterBody2D

# ==============================================================================
# CONSTANTES
# ==============================================================================
const SPEED := 50.0
const ATTACK_DAMAGE := 10
const ATTACK_RANGE := 60.0
const CHASE_RANGE := 200

# ==============================================================================
# NÓS REFERENCIADOS
# ==============================================================================
@onready var _sprite: AnimatedSprite2D = $ansprRed_Soldier
@onready var _hitbox_col: CollisionShape2D = $aHitbox/colHitbox
@onready var _hitbox: Area2D = $aHitbox
@onready var _hurtbox_col: CollisionShape2D = $aHurtbox/colHurtbox
@onready var _hurtbox: Area2D = $aHurtbox

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
	_hurtbox_col.disabled = false
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.frame_changed.connect(_on_frame_changed)
	# <- ATUALIZADO: detecta Area2D ao invés de body
	_hitbox.area_entered.connect(_on_hitbox_area_entered)

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
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]

func _try_attack() -> void:
	if _player == null:
		return

	var distance := global_position.distance_to(_player.global_position)

	if distance <= ATTACK_RANGE:
		_direction = 1 if _player.global_position.x > global_position.x else -1
		start_attack()

# ==============================================================================
# ANIMAÇÕES
# ==============================================================================
func _update_animation() -> void:
	_sprite.flip_h = _direction < 0

	if _hitbox.position.x != 0:
		_hitbox.position.x = abs(_hitbox.position.x) * _direction
	if _hitbox_col.position.x != 0:
		_hitbox_col.position.x = abs(_hitbox_col.position.x) * _direction

	if _is_attacking:
		return

	if is_on_floor():
		_sprite.play("walk")

# ==============================================================================
# HITBOX - Ativa só nos frames de impacto
# ==============================================================================
func _on_frame_changed() -> void:
	if _sprite.animation == "attack":
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

# <- ATUALIZADO: detecta o aHitbox do player pelo grupo
func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("hitbox_player"):
		var player = area.get_parent()
		if player.has_method("take_damage"):
			player.take_damage(ATTACK_DAMAGE)
