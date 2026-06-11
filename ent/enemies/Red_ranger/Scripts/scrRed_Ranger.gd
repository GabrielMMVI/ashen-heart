extends CharacterBody2D

# ==============================================================================
# CONSTANTES
# ==============================================================================
const SPEED_WALK        := 50.0    # Velocidade de movimentação geral
const SPEED_RETREAT     := 90.0    # Velocidade ao recuar (um pouco mais rápido)
const ARROW_SPEED_X     := 350.0   # Velocidade horizontal da flecha
const MAX_HEALTH        := 50
const JUMP_VELOCITY     := -250
const JUMP_COOLDOWN     := 0.70

# ── Ranges de comportamento (lógica estilo Minecraft Skeleton) ─────────────────
#
#   |← RETREAT_RANGE →|← IDLE_RANGE →|← DETECTION_RANGE →|
#   [====RECUA==========[===ATIRA=======[===ALERTA/IDLE=======]
#
#   < RETREAT_RANGE      → player muito perto → recua
#   RETREAT_RANGE ~ PREFERRED_RANGE → faixa ideal → atira parado
#   > DETECTION_RANGE    → player longe demais → IDLE
#
const DETECTION_RANGE   := 280.0   # Até onde "enxerga" o player
const PREFERRED_RANGE   := 200.0   # Distância ideal para atirar (range máximo de tiro)
const RETREAT_RANGE     := 100.0   # Se o player chegar mais perto que isso → recua
const DISENGAGE_RANGE   := 400.0   # Se o player fugir além disso → volta ao IDLE

const ALERT_DURATION    := 0.5     # Pausa ao avistar o player (estilo Terraria)

# ==============================================================================
# ESTADOS DO INIMIGO
# Diagrama de transições:
#
#   IDLE ──(player entra em DETECTION_RANGE)──► ALERTED
#   ALERTED ──(timer esgota)──► COMBAT
#   COMBAT ──(dist > DISENGAGE_RANGE)──► IDLE
#   COMBAT ──(dist < RETREAT_RANGE)──► RETREATING
#   COMBAT ──(RETREAT_RANGE ≤ dist ≤ PREFERRED_RANGE)──► atira parado
#   COMBAT ──(dist > PREFERRED_RANGE)──► anda para frente até preferred range
#   RETREATING ──(dist ≥ PREFERRED_RANGE)──► COMBAT  (reposiciona até a faixa ideal)
#   qualquer ──(take_damage com knockback)──► KNOCKBACK
#   KNOCKBACK ──(timer esgota)──► COMBAT ou IDLE
# ==============================================================================
enum State { PATROL, IDLE, ALERTED, COMBAT, RETREATING, KNOCKBACK }

# ==============================================================================
# NÓS REFERENCIADOS & EXPORTS
# ==============================================================================
@export var knockback_resistance: float = 15.0

@export var arrow_scene: PackedScene = preload("res://ent/projectiles/basic_Arrow/arrow_scene.tscn")
@onready var _sprite:       AnimatedSprite2D = $ansprRed_Ranger
@onready var _shoot_point:  Marker2D         = $mkShoot

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================
var _direction:      int   = -1
var _player:         Node2D = null
var _current_health: int   = MAX_HEALTH
var _state:          State = State.IDLE
var _alert_timer:    float = 0.0
var _is_attacking:   bool  = false  # true enquanto a animação de ataque roda
var _jump_timer            := 0.0 

# ==============================================================================
# PRONTO
# ==============================================================================
func _ready() -> void:
	_current_health = MAX_HEALTH
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.frame_changed.connect(_on_frame_changed)

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
		State.IDLE:       _process_idle()
		State.PATROL:     _process_patrol()
		State.ALERTED:    _process_alerted(delta)
		State.COMBAT:     _process_combat()
		State.RETREATING: _process_retreating(delta)
		State.KNOCKBACK:  pass   # Controlado pelo timer de knockback


# Patrol
# Patrulha vagarosamente. Inverte direção ao bater na parede.
# Assim que o player entra no range de detecção, entra em alerta.
func _process_patrol() -> void:
	if is_on_wall():
		_direction *= -1
	velocity.x = _direction * SPEED_WALK

	if not is_instance_valid(_player):
		return

	var dist := global_position.distance_to(_player.global_position)
	if dist <= DETECTION_RANGE:
		_direction = sign(_player.global_position.x - global_position.x)
		_alert_timer = ALERT_DURATION
		_transition_to(State.ALERTED)

# ── IDLE ──────────────────────────────────────────────────────────────────────
func _process_idle() -> void:
	velocity.x = 0
	if not is_instance_valid(_player):
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist <= DETECTION_RANGE - 50:
		_transition_to(State.RETREATING)
	

# ── ALERTED ───────────────────────────────────────────────────────────────────
# Pausa dramática ao avistar o player antes de entrar em combate.
func _process_alerted(delta: float) -> void:
	velocity.x = 0
	_alert_timer -= delta
	if _alert_timer <= 0.0:
		_transition_to(State.COMBAT)

# ── COMBAT ────────────────────────────────────────────────────────────────────
# Núcleo da IA estilo Skeleton do Minecraft:
#   • Se o player chegar perto demais → RETREATING
#   • Se o player estiver na faixa ideal → fica parado e atira
#   • Se o player estiver longe demais → anda devagar em direção a ele
#   • Se o player sumir → IDLE
func _process_combat() -> void:
	if not is_instance_valid(_player):
		_transition_to(State.IDLE)
		return

	var dist := global_position.distance_to(_player.global_position)

	# Player fugiu longe demais → desengaja:
	# vira as costas, cancela ataque e volta a patrulhar
	if dist > DISENGAGE_RANGE:
		_is_attacking = false
		_direction = -sign(_player.global_position.x - global_position.x)
		_transition_to(State.IDLE)
		return

	# Sempre olha para o player no estado de combate
	_direction = sign(_player.global_position.x - global_position.x)

	# Player chegou perto demais → cancela ataque e recua para reposicionar
	if dist < RETREAT_RANGE:
		_is_attacking = false
		_transition_to(State.RETREATING)
		return

	# Player está além do range ideal → se aproxima caminhando
	if dist > PREFERRED_RANGE:
		velocity.x = _direction * SPEED_WALK
	else:
		# Faixa ideal: para no lugar e atira
		velocity.x = 0
		_try_start_attack()

# ── RETREATING ────────────────────────────────────────────────────────────────
# Player chegou perto demais: arqueiro dá as costas e corre até a faixa ideal
# de tiro (PREFERRED_RANGE), sem atacar durante o reposicionamento.
func _process_retreating(delta: float) -> void:
	if not is_instance_valid(_player):
		_transition_to(State.IDLE)
		return

	var dist := global_position.distance_to(_player.global_position)

	# Alcançou a faixa ideal → retoma combate com posição vantajosa
	if dist >= PREFERRED_RANGE:
		_transition_to(State.COMBAT)
		return

	# Costas para o player: _direction aponta para longe dele
	_direction = -sign(_player.global_position.x - global_position.x)
	velocity.x = _direction * SPEED_RETREAT
	
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
# TRANSIÇÃO DE ESTADO — ponto único de mudança
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

	if applied_knockback_force != Vector2.ZERO:
		var kx: float = max(0.0, abs(applied_knockback_force.x) - knockback_resistance)
		var ky: float = max(0.0, abs(applied_knockback_force.y) - knockback_resistance)
		velocity.x = kx * sign(applied_knockback_force.x)
		velocity.y = ky * sign(applied_knockback_force.y)

		if kx > 0.0 or ky > 0.0:
			_transition_to(State.KNOCKBACK)
			get_tree().create_timer(0.3).timeout.connect(_on_knockback_ended)

	_flash_damage()
	print("Atirador Vermelho recebeu dano! Vida: ", _current_health, "/", MAX_HEALTH)

	if _current_health == 0:
		_die()

func _on_knockback_ended() -> void:
	if is_instance_valid(_player):
		_transition_to(State.COMBAT)
	else:
		_transition_to(State.IDLE)

func _die() -> void:
	print("Atirador Vermelho morreu!")
	await get_tree().create_timer(0.5).timeout
	set_physics_process(false)
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
# Busca no grupo apenas quando a referência está inválida.
# ==============================================================================
func _find_player() -> void:
	if is_instance_valid(_player):
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]

# ==============================================================================
# ATAQUE — dispara apenas se a animação anterior terminou
# ==============================================================================
func _try_start_attack() -> void:
	if _is_attacking:
		return
	_is_attacking = true
	_sprite.play("attack")

# ==============================================================================
# ANIMAÇÕES
# ==============================================================================
func _update_animation() -> void:
	# O sprite sempre aponta para o player (mesmo ao recuar)
	_sprite.flip_h = (_direction < 0)

	# Não interrompe animação de ataque ou knockback
	if _is_attacking or _state == State.KNOCKBACK:
		return

	match _state:
		State.IDLE:
			# Patrulhando: retoma "walk" sempre que não estiver tocando corretamente
			if _sprite.animation != "walk" or not _sprite.is_playing():
				_sprite.play("walk")
		State.ALERTED:
			# Pausa dramática ao avistar o player
			# Substitua "idle" pelo nome real da animação parada se necessário
			if _sprite.animation != "idle" or not _sprite.is_playing():
				_sprite.play("idle")
		State.COMBAT:
			if velocity.x != 0.0:
				# Se aproximando do player
				if _sprite.animation != "walk" or not _sprite.is_playing():
					_sprite.play("walk")
			else:
				# Parado na faixa ideal, pronto para atirar
				if _sprite.animation != "idle" or not _sprite.is_playing():
					_sprite.play("idle")
		State.RETREATING:
			# Recuando: retoma "walk" sempre que não estiver tocando corretamente
			if _sprite.animation != "walk" or not _sprite.is_playing():
				_sprite.play("walk")

func _on_frame_changed() -> void:
	# Instancia a flecha no frame exato em que o arco é solto.
	# Ajuste o número "5" para o frame correto da sua animação.
	if _sprite.animation == "attack" and _sprite.frame == 5:
		_shoot_arrow()

func _on_animation_finished() -> void:
	if _sprite.animation == "attack":
		_is_attacking = false
		# Não precisa re-disparar aqui: _try_start_attack() é
		# chamado a cada frame em COMBAT/RETREATING automaticamente.

# ==============================================================================
# PROJÉTIL
# ==============================================================================
func _shoot_arrow() -> void:
	if not arrow_scene:
		push_error("Arrow scene não atribuída no Red_Ranger!")
		return

	var arrow = arrow_scene.instantiate()
	get_tree().current_scene.add_child(arrow)

	var start_pos: Vector2 = _shoot_point.global_position if _shoot_point else global_position
	arrow.global_position = start_pos

	if is_instance_valid(_player) and arrow.has_method("fire"):
		var calculated_velocity := _calculate_trajectory(start_pos, _player.global_position)
		arrow.fire(calculated_velocity)

func _calculate_trajectory(start: Vector2, target: Vector2) -> Vector2:
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	var displacement := target - start

	# Tempo de voo baseado na distância horizontal com velocidade fixa.
	# Clamp mínimo evita divisão por zero.
	var time_of_flight: float = max(0.01, abs(displacement.x) / ARROW_SPEED_X)

	# Velocidade X: direção com módulo constante
	var vel_x: float = ARROW_SPEED_X * sign(displacement.x)

	# Velocidade Y para atingir o alvo exatamente no tempo calculado.
	# Fórmula da cinemática: Vy = (Δy - ½·g·t²) / t
	var vel_y: float = (displacement.y - 0.5 * gravity * time_of_flight * time_of_flight) / time_of_flight

	return Vector2(vel_x, vel_y)
