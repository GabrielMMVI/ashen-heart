extends CharacterBody2D

# ==============================================================================
# CONSTANTES
# ==============================================================================
const SPEED_CHASE       := 120.0          # Velocidade ao perseguir (mais agressiva)
const ATTACK_DAMAGE     := 10
const ATTACK_RANGE      := 20.0          # Distância para iniciar o ataque
const DETECTION_RANGE   := 110.0         # Distância para "enxergar" o player
const DISENGAGE_RANGE   := 170.0         # Distância para desistir da perseguição
const MAX_HEALTH        := 100
const KNOCKBACK_FORCE   := Vector2(200.0, -50.0)
const JUMP_VELOCITY     := -150.0        # Força do pulo para superar obstáculos
const ALERT_DURATION    := 0.55          # Segundos parado ao avistar o player
const JUMP_COOLDOWN     := 0.75          # Intervalo mínimo entre pulos

# ==============================================================================
# ESTADOS DO INIMIGO
# Diagrama de transições:
#
#   IDLE ──(player entra em DETECTION_RANGE)──► ALERTED
#   ALERTED ──(timer esgota)──► CHASE
#   CHASE ──(player entra em ATTACK_RANGE)──► ATTACK
#   CHASE ──(player sai de DISENGAGE_RANGE)──► IDLE
#   ATTACK ──(animação termina)──► CHASE ou IDLE
#   qualquer ──(take_damage com knockback)──► KNOCKBACK
#   KNOCKBACK ──(timer esgota)──► CHASE ou IDLE
# ==============================================================================
enum State {IDLE, PATROL ,ALERTED, CHASE, ATTACK, KNOCKBACK }

# ==============================================================================
# NÓS REFERENCIADOS
# ==============================================================================
@export var knockback_resistance: float = 35.0

@onready var _sprite:      AnimatedSprite2D = $ansprRed_Soldier
@onready var _hitbox_col:  CollisionShape2D = $aHitbox/colHitbox
@onready var _hitbox:      Area2D           = $aHitbox

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================
var _direction      := -1
var _player:  Node2D = null
var _current_health := MAX_HEALTH
var _state          := State.IDLE
var _alert_timer    := 0.0
var _jump_timer     := 0.0

# ==============================================================================
# PRONTO
# ==============================================================================
func _ready() -> void:
	_current_health = MAX_HEALTH
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.frame_changed.connect(_on_frame_changed)
	_hitbox.area_entered.connect(_on_hitbox_area_entered)

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
		State.IDLE:      _process_idle()
		State.PATROL:    _process_patrol()
		State.ALERTED:   _process_alerted(delta)
		State.CHASE:     _process_chase(delta)
		State.ATTACK:    pass   # Controlado pelos callbacks de animação
		State.KNOCKBACK: pass   # Controlado pelo timer de knockback


# IDLE
func _process_idle() -> void:
	velocity.x = 0
	if not is_instance_valid(_player):
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist <= DETECTION_RANGE - 50:
		_transition_to(State.CHASE)
	
	

# ── Patrol ──────────────────────────────────────────────────────────────────────
# Patrulha vagarosamente. Inverte direção ao bater na parede.
# Assim que o player entra no range de detecção, entra em alerta.
func _process_patrol() -> void:
	if is_on_wall():
		_direction *= -1
	velocity.x = _direction * 50.0   # Velocidade de patrulha (ajuste à vontade)

	if not is_instance_valid(_player):
		return

	var dist := global_position.distance_to(_player.global_position)

	if dist <= DETECTION_RANGE:
		# Viu o player: olha para ele e entra em estado de alerta
		_direction = sign(_player.global_position.x - global_position.x)
		_alert_timer = ALERT_DURATION
		_transition_to(State.ALERTED)

# ── ALERTED ───────────────────────────────────────────────────────────────────
# Inimigo acaba de notar o player. Fica parado por ALERT_DURATION segundos
# antes de começar a corrida (comportamento clássico de Terraria).
func _process_alerted(delta: float) -> void:
	velocity.x = 0
	_alert_timer -= delta

	if _alert_timer <= 0.0:
		_transition_to(State.CHASE)

# ── CHASE ─────────────────────────────────────────────────────────────────────
# Inimigo corre em direção ao player, pula obstáculos e decide quando atacar.
func _process_chase(delta: float) -> void:
	if not is_instance_valid(_player):
		_transition_to(State.PATROL)
		return

	var dist := global_position.distance_to(_player.global_position)

	# Player saiu do alcance máximo → desiste e volta a ficar parado
	if dist > DISENGAGE_RANGE:
		_transition_to(State.PATROL)
		return

	# Player está em alcance de ataque → para e ataca
	if dist <= ATTACK_RANGE:
		_direction = sign(_player.global_position.x - global_position.x)
		_try_start_attack()
		return

	# ── Movimento de perseguição ──────────────────────────────────────────────
	_direction = sign(_player.global_position.x - global_position.x)
	velocity.x = _direction * SPEED_CHASE

	# ── Lógica de pulo (obstáculos e plataformas) ─────────────────────────────
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
# Ponto único de mudança de estado — facilita debug e extensão futura.
# ==============================================================================
func _transition_to(new_state: State) -> void:
	_state = new_state

# ==============================================================================
# SISTEMA DE VIDA
# ==============================================================================
func take_damage(amount: int, applied_knockback_force: Vector2 = Vector2.ZERO) -> void:
	if _current_health <= 0:
		return

	_current_health = max(0, _current_health - amount)

	# Knockback com resistência
	if applied_knockback_force != Vector2.ZERO:
		var kx: float = max(0.0, abs(applied_knockback_force.x) - knockback_resistance)
		var ky: float = max(0.0, abs(applied_knockback_force.y) - knockback_resistance)
		velocity.x = kx * sign(applied_knockback_force.x)
		velocity.y = ky * sign(applied_knockback_force.y)

		if kx > 0.0 or ky > 0.0:
			_transition_to(State.KNOCKBACK)
			get_tree().create_timer(0.3).timeout.connect(_on_knockback_ended)

	_flash_damage()
	print("Soldado Vermelho recebeu dano! Vida: ", _current_health, "/", MAX_HEALTH)

	if _current_health == 0:
		_die()

func _on_knockback_ended() -> void:
	# Ao sair do knockback, retoma perseguição se o player ainda existir
	if is_instance_valid(_player):
		_transition_to(State.CHASE)
	else:
		_transition_to(State.IDLE)

func _die() -> void:
	print("Soldado Vermelho morreu!")
	queue_free()

func _flash_damage() -> void:
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color.RED,   0.1)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.1)

# ==============================================================================
# FÍSICA
# ==============================================================================
func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

# ==============================================================================
# DETECÇÃO DO PLAYER
# Busca no grupo "player" apenas quando a referência estiver inválida,
# evitando a busca desnecessária em toda frame.
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

	# Mantém a hitbox alinhada com a direção do sprite
	if _hitbox.position.x != 0:
		_hitbox.position.x     = abs(_hitbox.position.x) * _direction
	if _hitbox_col.position.x != 0:
		_hitbox_col.position.x = abs(_hitbox_col.position.x) * _direction

	# Não interrompe animações de ataque ou knockback
	if _state in [State.ATTACK, State.KNOCKBACK]:
		return

	match _state:
		State.IDLE:
			if _sprite.animation != "idle" or not _sprite.is_playing():
				_sprite.play("idle")
		State.PATROL:
			# Patrulhando: retoma "walk" sempre que não estiver tocando corretamente
			if _sprite.animation != "walk" or not _sprite.is_playing():
				_sprite.play("walk")
		State.ALERTED:
			# Pausa dramática ao avistar o player
			# Substitua "idle" pelo nome real da sua animação parada,
			# ou use _sprite.stop() se não houver animação de idle.
			if _sprite.animation != "idle" or not _sprite.is_playing():
				_sprite.play("idle")
		State.CHASE:
			# Perseguindo: retoma "walk" sempre que não estiver tocando corretamente
			if _sprite.animation != "walk" or not _sprite.is_playing():
				_sprite.play("walk")

func _on_frame_changed() -> void:
	if _sprite.animation == "attack":
		_hitbox_col.disabled = _sprite.frame not in [2, 3]

func _on_animation_finished() -> void:
	if _sprite.animation == "attack":
		_hitbox_col.disabled = true
		# Ao terminar o ataque, decide o próximo estado
		if is_instance_valid(_player):
			_transition_to(State.CHASE)
		else:
			_transition_to(State.IDLE)

# ==============================================================================
# ATAQUE
# ==============================================================================
func _try_start_attack() -> void:
	if _state == State.ATTACK:
		return
	velocity.x = 0
	_transition_to(State.ATTACK)
	_sprite.play("attack")

# ==============================================================================
# HITBOX — colisão com o player
# ==============================================================================
func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hurtbox"):
		var player = area.get_parent()
		if player.has_method("take_damage"):
			var applied_force := Vector2(KNOCKBACK_FORCE.x * _direction, KNOCKBACK_FORCE.y)
			player.take_damage(ATTACK_DAMAGE, applied_force)
