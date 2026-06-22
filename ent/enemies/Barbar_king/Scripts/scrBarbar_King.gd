extends CharacterBody2D

# -- Constantes ----------------------------------------------------------------
const MAX_HEALTH := 550
const WALK_SPEED := 60
const RUSH_SPEED := 125
const JUMP_VELOCITY     := -325.0        # Força do pulo para superar obstáculos
const JUMP_COOLDOWN := 0.80
const DASH_FRICTION := 700
const DASH_SPEED := 450
const KNOCKBACK_FORCE_CORONHA := Vector2(550, -160)
const KNOCKBACK_FORCE_MACHADO := Vector2(300, -10)

# -- Danos ---------------------------------------------------------------------
const CORONHA_DAMAGE := 60
const MACHADO_DAMAGE := 40

# -- Ranges --------------------------------------------------------------------
const DETECTION_RANGE := 120
const DASH_RANGE      := 100
const MACHADO_RANGE   := 30
const CORONHA_RANGE   := 18

# ── Cooldowns ─────────────────────────────────────────────────────────────────
const MACHADO_COOLDOWN_TIME := 3.0
const CORONHA_COOLDOWN_TIME := 3.5

# -- Estado do Boss ------------------------------------------------------------
# Diagrama de transições:
#
#   IDLE ──(dist ≤ DETECTION_RANGE)──────────────────────► WALK
#   WALK ──(dist ≤ CORONHA_RANGE  + cooldown = 0)────────► ATTACK_CORONHA (push)
#   WALK ──(dist ≤ MACHADO_RANGE  + cooldown = 0)────────► ATTACK_MACHADO
#   WALK ──(MACHADO_RANGE < dist ≤ DASH_RANGE + cooldown = 0)► ATTACK_CORONHA (dash)
#   ATTACK_* ──(animação termina)────────────────────────► WALK
#   qualquer ──(vida = 0)────────────────────────────────► DEAD
#
enum State { IDLE, WALK, ATTACK_CORONHA, ATTACK_MACHADO, DEAD }

@export var knockback_resistance: float = 250.0

@onready var _sprite:           AnimatedSprite2D = $ansprBoss2
@onready var _hitbox_coronha:   CollisionShape2D = $aHitbox/aHitboxCoronhada
@onready var _hitbox_machado:   CollisionShape2D = $aHitbox/aHitboxMachado
@onready var _hurtbox:          CollisionShape2D = $aHurtbox/aHurtbox

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================
var _direction:         int    = -1
var _player:            Node2D = null
var _current_health:    int    = MAX_HEALTH
var _state:             State  = State.IDLE
var _machado_cooldown:  float  = 0.0
var _coronha_cooldown:  float  = 0.0
var _coronha_is_dash:   bool   = false
var _jump_timer     := 0.0

# ==============================================================================
# PRONTO
# ==============================================================================
func _ready() -> void:
	add_to_group("enemy")

	# O nó Area2D do hurtbox precisa estar no grupo que as armas do player detectam.
	# Se as armas usam area_entered + is_in_group("enemy_hurtbox"), mantenha esta linha.
	# Se usam body_entered no CharacterBody2D, remova esta linha (o grupo "enemy" acima basta).
	$aHurtbox.add_to_group("enemy_hurtbox")

	_current_health = MAX_HEALTH
	_hitbox_coronha.disabled = true
	_hitbox_machado.disabled = true
	_sprite.frame_changed.connect(_on_frame_changed)
	$aHitbox.area_entered.connect(_on_hitbox_area_entered)

# ==============================================================================
# LOOP PRINCIPAL
# ==============================================================================
func _physics_process(delta: float) -> void:
	_handle_gravity(delta)
	_find_player()
	_tick_state(delta)
	_update_animation()
	move_and_slide()

# ==============================================================================
# MÁQUINA DE ESTADOS — dispatcher
# ==============================================================================
func _tick_state(delta: float) -> void:
	match _state:
		State.IDLE:            _process_idle()
		State.WALK:            _process_walk(delta)
		State.ATTACK_CORONHA:  _process_coronha(delta)
		State.ATTACK_MACHADO:  pass   # Controlado por await em _start_attack_machado
		State.DEAD:             pass   # Controlado por await em _start_death

# ── IDLE ──────────────────────────────────────────────────────────────────────
func _process_idle() -> void:
	velocity.x = 0.0
	if not is_instance_valid(_player):
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist <= DETECTION_RANGE:
		_machado_cooldown = 0.5
		_coronha_cooldown = 0.5
		_transition_to(State.WALK)

# ── WALK ──────────────────────────────────────────────────────────────────────
func _process_walk(delta: float) -> void:
	if not is_instance_valid(_player):
		velocity.x = 0.0
		return

	var dist := global_position.distance_to(_player.global_position)
	_direction = signi(int(_player.global_position.x - global_position.x))
	if _direction == 0: _direction = 1   # Prevenção de travamento

	velocity.x = _direction * WALK_SPEED
	

	_machado_cooldown = max(0.0, _machado_cooldown - delta)
	_coronha_cooldown = max(0.0, _coronha_cooldown - delta)

	# 1. Player colado: CORONHA defensiva (empurra para longe)
	if dist <= CORONHA_RANGE and _coronha_cooldown <= 0.0:
		_start_attack_coronha(false)
		return

	# 2. Player em range do machado
	if dist <= MACHADO_RANGE and _machado_cooldown <= 0.0:
		_start_attack_machado()
		return

	# 3. Player além do machado mas dentro do dash range: CORONHA ofensiva
	if dist <= DASH_RANGE and dist > MACHADO_RANGE and _coronha_cooldown <= 0.0:
		_start_attack_coronha(true)
		return
		
	_jump_timer -= delta
	if is_on_floor() and _jump_timer <= 0.0:
		var should_jump := false

		# Pulo reativo: bateu em uma parede durante a corrida
		if is_on_wall():
			should_jump = true

		# Pulo proativo: player está significativamente acima do inimigo
		if _player.global_position.y < global_position.y - 50.0:
			should_jump = true

		if should_jump:
			velocity.y   = JUMP_VELOCITY
			_jump_timer  = JUMP_COOLDOWN

# ==============================================================================
# TRANSIÇÃO DE ESTADO
# ==============================================================================
func _transition_to(new_state: State) -> void:
	_state = new_state

func _return_to_walk() -> void:
	_transition_to(State.WALK)

# ==============================================================================
# ATTACK_MACHADO — corte de machado, boss parado
# ==============================================================================
func _start_attack_machado() -> void:
	if _state == State.ATTACK_MACHADO:
		return
	_transition_to(State.ATTACK_MACHADO)
	velocity.x        = 0.0
	_machado_cooldown = MACHADO_COOLDOWN_TIME
	_sprite.play("attack")

	await _sprite.animation_finished

	_hitbox_machado.disabled = true
	if _state == State.ATTACK_MACHADO:
		_return_to_walk()

func _enable_machado_hitbox() -> void:
	_hitbox_machado.disabled = false

# ==============================================================================
# ATTACK_CORONHA — dois tipos controlados por _coronha_is_dash
#
#   is_dash = false → boss para, executa a coronhada e empurra o player
#   is_dash = true  → telegraf de 1s → impulso total que decai até parar
# ==============================================================================
func _start_attack_coronha(is_dash: bool) -> void:
	if _state == State.ATTACK_CORONHA:
		return
	_coronha_is_dash  = is_dash
	_coronha_cooldown = CORONHA_COOLDOWN_TIME
	_transition_to(State.ATTACK_CORONHA)

	if is_dash:
		# Telegraf: para, pisca vermelho por 1s, depois dispara
		velocity.x = 0.0
		_sprite.play("idle")
		_flash_telegraph()
		_enable_coronha_hitbox()

		await get_tree().create_timer(1.0).timeout
		if _state != State.ATTACK_CORONHA:   # Morreu durante o telegraf
			return

		# Impulso completo e animação do ataque
		velocity.x = _direction * DASH_SPEED
		_sprite.play("2nd_attack")
		await _sprite.animation_finished
	else:
		# Push defensivo: parado, só a animação e a hitbox
		velocity.x = 0.0
		_sprite.play("2nd_attack")
		await _sprite.animation_finished

	_hitbox_coronha.disabled = true
	if _state == State.ATTACK_CORONHA:
		_return_to_walk()

# Desacelera o deslize suavemente a cada frame durante o dash
func _process_coronha(delta: float) -> void:
	if _coronha_is_dash:
		velocity.x = move_toward(velocity.x, 0.0, DASH_FRICTION * delta)

# Dois piscados vermelhos antes do dash — aviso visual ao player
func _flash_telegraph() -> void:
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color.RED,   0.15)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.15)
	tween.tween_interval(0.2)
	tween.tween_property(_sprite, "modulate", Color.RED,   0.15)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.15)

func _enable_coronha_hitbox() -> void:
	_hitbox_coronha.disabled = false

# ==============================================================================
# SISTEMA DE VIDA
# ==============================================================================
func take_damage(amount: int, _applied_knockback_force: Vector2 = Vector2.ZERO) -> void:
	# Boss não sofre knockback — parâmetro ignorado intencionalmente
	if _current_health <= 0:
		return
	_current_health = max(0, _current_health - amount)
	_flash_damage()
	print("Boss 2 recebeu dano! Vida: ", _current_health, "/", MAX_HEALTH)
	if _current_health == 0:
		_start_death()

func _flash_damage() -> void:
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color.RED,   0.1)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.1)

# ==============================================================================
# MORTE
# ==============================================================================
func _start_death() -> void:
	_transition_to(State.DEAD)
	velocity             = Vector2.ZERO
	_hitbox_coronha.disabled = true
	_hitbox_machado.disabled = true
	_sprite.play("death")
	print("Boss 2 morreu!")

	await get_tree().create_timer(3.0).timeout
	queue_free()

# ==============================================================================
# FÍSICA
# ==============================================================================
func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

# ==============================================================================
# DETECÇÃO DO PLAYER
# ==============================================================================
func _find_player() -> void:
	if is_instance_valid(_player):
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]

# ==============================================================================
# ANIMAÇÕES
# ==============================================================================
func _update_animation() -> void:
	_sprite.flip_h = (_direction < 0)

	if _hitbox_coronha.position.x != 0:
		_hitbox_coronha.position.x = abs(_hitbox_coronha.position.x) * _direction
	if _hitbox_machado.position.x != 0:
		_hitbox_machado.position.x = abs(_hitbox_machado.position.x) * _direction

	if _state in [State.ATTACK_CORONHA, State.ATTACK_MACHADO, State.DEAD]:
		return

	match _state:
		State.IDLE:
			if _sprite.animation != "idle" or not _sprite.is_playing():
				_sprite.play("idle")
		State.WALK:
			if _sprite.animation != "walk" or not _sprite.is_playing():
				_sprite.play("walk")

func _on_frame_changed() -> void:
	if _sprite.animation == "attack" and _sprite.frame == 3:
		_enable_machado_hitbox()
	elif _sprite.animation == "2nd_attack" and _sprite.frame == 2:
		_enable_coronha_hitbox()

# ==============================================================================
# HITBOX — colisão com o player
# ==============================================================================
func _on_hitbox_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player_hurtbox"):
		return
	var player := area.get_parent()
	if not player.has_method("take_damage"):
		return

	if _state == State.ATTACK_MACHADO and not _hitbox_machado.disabled:
		var force := Vector2(KNOCKBACK_FORCE_MACHADO.x * _direction, KNOCKBACK_FORCE_MACHADO.y)
		player.take_damage(MACHADO_DAMAGE, force)

	elif _state == State.ATTACK_CORONHA and not _hitbox_coronha.disabled:
		var force := Vector2(KNOCKBACK_FORCE_CORONHA.x * _direction, KNOCKBACK_FORCE_CORONHA.y)
		player.take_damage(CORONHA_DAMAGE, force)
