extends CharacterBody2D

# ==============================================================================
# CONSTANTES
# ==============================================================================
const SPEED := 50.0
const ATTACK_DAMAGE := 10
const ATTACK_RANGE := 60.0
const CHASE_RANGE := 200
const MAX_HEALTH := 100
const KNOCKBACK_FORCE := Vector2(200.0, -50.0)

# ==============================================================================
# NÓS REFERENCIADOS
# ==============================================================================
@export var knockback_resistance := 35 

@onready var _sprite: AnimatedSprite2D = $ansprRed_Soldier
@onready var _hitbox_col: CollisionShape2D = $aHitbox/colHitbox
@onready var _hitbox: Area2D = $aHitbox

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================
var _direction := -1
var _is_attacking := false
var _player: Node2D = null
var _current_health = MAX_HEALTH
var _is_knocked_back := false

# ==============================================================================
# PRONTO
# ==============================================================================
func _ready() -> void:
	_current_health = MAX_HEALTH
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.frame_changed.connect(_on_frame_changed)
	# <- ATUALIZADO: detecta Area2D ao invés de body
	_hitbox.area_entered.connect(_on_hitbox_area_entered)
	

# ==============================================================================
# LOOP PRINCIPAL
# ==============================================================================
func _physics_process(delta: float) -> void:
	_handle_gravity(delta)
	
	if _is_knocked_back:
		move_and_slide()
		return
		
	_find_player()
	
	if not _is_attacking:
		_try_attack()
		_handle_movement()
	
	_update_animation()
	move_and_slide()

# ==============================================================================
# SISTEMA DE VIDA
# ==============================================================================
func take_damage(amount: int, applied_knockback_force: Vector2 = Vector2.ZERO) -> void:
	if _current_health <= 0:
		return
		
	_current_health -= amount
	_current_health = max(0, _current_health)
	
	# CÁLCULO DO KNOCKBACK COM RESISTÊNCIA
	if applied_knockback_force != Vector2.ZERO:
		# Subtrai a resistência da força aplicada (garante que não inverta o lado se a resistência for muito alta)
		var final_knockback_x = max(0, abs(applied_knockback_force.x) - knockback_resistance)
		var final_knockback_y = max(0, abs(applied_knockback_force.y) - knockback_resistance)
		
		# Mantém a direção original do ataque, mas com a força reduzida
		velocity.x = final_knockback_x * sign(applied_knockback_force.x)
		
		# O eixo Y geralmente é negativo no Godot para ir para cima, então preservamos o sinal original
		velocity.y = final_knockback_y * sign(applied_knockback_force.y)
		
		# Só aplica o estado se a força final for maior que zero (ou seja, se a resistência não anulou o golpe)
		if final_knockback_x > 0 or final_knockback_y > 0:
			_is_knocked_back = true
			var timer = get_tree().create_timer(0.3)
			timer.timeout.connect(func(): _is_knocked_back = false)
	
	_flash_damage()
	
	# Debug no console
	print("Soldado Vermelho recebeu dano! Vida atual: ", _current_health, "/", MAX_HEALTH)
	
	if _current_health == 0:
		_die()

func _die() -> void:
	print("Soldado Vermelho morreu!")
	# Remove o nó do inimigo da cena com segurança, liberando a memória
	queue_free()
	
func _flash_damage() -> void:
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.1)
	
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
	if area.is_in_group("player_hurtbox"):
		var player = area.get_parent()
		if player.has_method("take_damage"):
			var applied_force = Vector2(KNOCKBACK_FORCE.x * _direction, KNOCKBACK_FORCE.y)
			player.take_damage(ATTACK_DAMAGE, applied_force)
