extends CharacterBody2D

# ==============================================================================
# CONSTANTES
# ==============================================================================
const MAX_HEALTH        := 870
const WALK_SPEED         := 40.0
const WALK_SPEED_PHASE2  := WALK_SPEED * 1.4   # +40% de velocidade na fase 2
const JUMP_VELOCITY      := -500.0
const KNOCKBACK_FORCE    := Vector2(400.0, -50.0)

# ── Danos ────────────────────────────────────────────────────────────────────
const PIERCE_DAMAGE := 80
const SLASH_DAMAGE  := 60
const MAGIC_DAMAGE   := 100

# ── Ranges ───────────────────────────────────────────────────────────────────
const SLASH_RANGE       := 40.0
const PIERCE_RANGE      := 60.0
const PIERCE_RANGE_P2   := 90.0    # Fase 2: estoca de mais longe
const MAGIC_RANGE       := 160.0
const DETECTION_RANGE   := 120.0

# ── Estocada (Pierce) ────────────────────────────────────────────────────────
const PIERCE_DASH_SPEED  := 320.0  # Velocidade inicial do deslize
const PIERCE_FRICTION    := 500.0  # Desaceleração do deslize (px/s²)

# ── Magia ────────────────────────────────────────────────────────────────────
const MAGIC_ALERT_DURATION := 1.0  # Tempo que o alerta fica em tela antes de explodir

# ── Intervalo entre ataques ─────────────────────────────────────────────────
const ATTACK_COOLDOWN       := 3.0  # Fase 1: tempo mínimo andando antes de novo ataque
const ATTACK_COOLDOWN_PHASE2 := 2.0 # Fase 2: intervalo reduzido

# ==============================================================================
# ESTADOS DO BOSS
# Diagrama de transições:
#
#   IDLE ──(player entra em DETECTION_RANGE)──► WALK
#   WALK ──(cooldown zerado + dist ≤ SLASH_RANGE)──► ATTACK_SLASH
#   WALK ──(cooldown zerado + dist ≤ PIERCE_RANGE)──► ATTACK_PIERCE
#   WALK ──(cooldown zerado + dist ≤ MAGIC_RANGE)──► ATTACK_MAGIC
#   ATTACK_* ──(animação/sequência termina)──► WALK (reinicia cooldown)
#   qualquer ──(vida chega a 0)──► DEAD
#
# Exceção: SLASH ignora o cooldown se o player estiver colado nele
# (ataque reativo de "alguém entrou no meu range de corte").
# ==============================================================================
enum State { IDLE, WALK, ATTACK_MAGIC, ATTACK_PIERCE, ATTACK_SLASH, DEAD }

@export var knockback_resistance: float = 500.0

@export var magic_alert_scene: PackedScene     = preload("res://ent/enemies/Maximos/Maximos_Magic_Ball/Magic_Alert.tscn")
@export var magic_explosion_scene: PackedScene = preload("res://ent/enemies/Maximos/Maximos_Magic_Ball/Explosion.tscn")

@onready var _sprite:        AnimatedSprite2D  = $ansprMaximos
@onready var _hurtbox:       CollisionShape2D  = $aHitBox/aHurtbox
@onready var _hitbox_Slash:  CollisionShape2D  = $aHitBox/aHitbox_Slash
@onready var _hitbox_Pierce: CollisionShape2D  = $aHitBox/aHitbox_Pierce

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================
var _direction:        int    = -1
var _player:            Node2D = null
var _current_health:    int    = MAX_HEALTH
var _state:             State  = State.IDLE
var _is_phase2:          bool   = false
var _attack_cooldown_timer: float = 0.0   # Tempo restante de WALK antes de poder atacar de novo

# ==============================================================================
# PRONTO
# ==============================================================================
func _ready() -> void:
	add_to_group("enemy")
	_current_health = MAX_HEALTH
	_hitbox_Slash.disabled  = true
	_hitbox_Pierce.disabled = true
	# Conexões de sinais
	_sprite.frame_changed.connect(_on_frame_changed)
	$aHitBox.area_entered.connect(_on_hitbox_area_entered)

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
		State.IDLE:          _process_idle()
		State.WALK:           _process_walk(delta)
		State.ATTACK_MAGIC:   pass   # Controlado pela sequência de await
		State.ATTACK_PIERCE:  _process_pierce(delta)
		State.ATTACK_SLASH:   pass   # Controlado pela sequência de await
		State.DEAD:            pass   # Controlado pela sequência de morte

# ── IDLE ──────────────────────────────────────────────────────────────────────
# Boss completamente parado até o player chegar perto o suficiente.
func _process_idle() -> void:
	velocity.x = 0.0

	if not is_instance_valid(_player):
		return

	var dist := global_position.distance_to(_player.global_position)
	if dist <= DETECTION_RANGE:
		# Inicia o cooldown para que o boss ande antes do primeiro ataque
		_attack_cooldown_timer = ATTACK_COOLDOWN_PHASE2 if _is_phase2 else ATTACK_COOLDOWN
		_transition_to(State.WALK)

# ── WALK ──────────────────────────────────────────────────────────────────────
# Anda em direção ao player. Só pode iniciar um novo ataque depois que o
# cooldown zerar — exceção: SLASH dispara a qualquer momento se o player
# estiver colado nele.
func _process_walk(delta: float) -> void:
	if not is_instance_valid(_player):
		velocity.x = 0.0
		return

	var dist := global_position.distance_to(_player.global_position)
	_direction = sign(_player.global_position.x - global_position.x)
	velocity.x = _direction * _current_walk_speed()

	# SLASH ignora o cooldown: reação imediata a curta distância
	if dist <= SLASH_RANGE:
		_start_attack_slash()
		return

	# Decrementa o cooldown enquanto anda
	_attack_cooldown_timer = max(0.0, _attack_cooldown_timer - delta)
	if _attack_cooldown_timer > 0.0:
		return

	# Cooldown zerado: escolhe o ataque pela distância
	var pierce_range := PIERCE_RANGE_P2 if _is_phase2 else PIERCE_RANGE

	if dist <= pierce_range:
		_start_attack_pierce()
	elif dist <= MAGIC_RANGE:
		_start_attack_magic()

func _current_walk_speed() -> float:
	return WALK_SPEED_PHASE2 if _is_phase2 else WALK_SPEED

# ==============================================================================
# TRANSIÇÃO DE ESTADO — ponto único de mudança
# ==============================================================================
func _transition_to(new_state: State) -> void:
	_state = new_state

# Chamado ao final de qualquer ataque: volta a andar e reinicia o cooldown.
func _return_to_walk() -> void:
	_attack_cooldown_timer = ATTACK_COOLDOWN_PHASE2 if _is_phase2 else ATTACK_COOLDOWN
	_transition_to(State.WALK)

# ==============================================================================
# ATTACK_SLASH — corte de espada corpo a corpo
# ==============================================================================
func _start_attack_slash() -> void:
	if _state == State.ATTACK_SLASH:
		return
	_transition_to(State.ATTACK_SLASH)
	velocity.x = 0.0
	_sprite.play("Slash_Attack")

	await _sprite.animation_finished

	_hitbox_Slash.disabled = true
	if _state == State.ATTACK_SLASH:   # Garante que não foi interrompido pela morte
		_return_to_walk()

# Ativa a hitbox no frame de impacto do corte (chamado por _on_frame_changed)
func _enable_slash_hitbox() -> void:
	_hitbox_Slash.disabled = false

# ==============================================================================
# ATTACK_PIERCE — estocada com deslize
# ==============================================================================
func _start_attack_pierce() -> void:
	if _state == State.ATTACK_PIERCE:
		return
	_transition_to(State.ATTACK_PIERCE)

	# Impulso inicial do deslize, na direção atual do boss
	velocity.x = _direction * PIERCE_DASH_SPEED
	_sprite.play("Pierce_Attack")

	await _sprite.animation_finished

	_hitbox_Pierce.disabled = true
	if _state == State.ATTACK_PIERCE:
		_return_to_walk()

# Desacelera o deslize a cada frame enquanto o estado ATTACK_PIERCE está ativo
func _process_pierce(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, PIERCE_FRICTION * delta)

# Ativa a hitbox no frame de impacto da estocada (chamado por _on_frame_changed)
func _enable_pierce_hitbox() -> void:
	_hitbox_Pierce.disabled = false

# ==============================================================================
# ATTACK_MAGIC — alerta seguido de explosão na posição do player
# ==============================================================================
func _start_attack_magic() -> void:
	if _state == State.ATTACK_MAGIC:
		return
	_transition_to(State.ATTACK_MAGIC)
	velocity.x = 0.0
	_sprite.play("Magic_Attack")

	if is_instance_valid(_player):
		var target_pos: Vector2 = _player.global_position
		_spawn_magic_alert(target_pos)

		await get_tree().create_timer(MAGIC_ALERT_DURATION).timeout

		if _state == State.ATTACK_MAGIC:   # Ainda vivo e não interrompido
			_spawn_magic_explosion(target_pos)

	if _state == State.ATTACK_MAGIC:
		_return_to_walk()

func _spawn_magic_alert(target_pos: Vector2) -> void:
	if not magic_alert_scene:
		push_error("Magic Alert scene não atribuída no Boss!")
		return
	var alert = magic_alert_scene.instantiate()
	get_tree().current_scene.add_child(alert)
	alert.global_position = target_pos

func _spawn_magic_explosion(target_pos: Vector2) -> void:
	if not magic_explosion_scene:
		push_error("Magic Explosion scene não atribuída no Boss!")
		return
	var explosion = magic_explosion_scene.instantiate()
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = target_pos
	if explosion.has_method("detonate"):
		explosion.detonate(MAGIC_DAMAGE)

# ==============================================================================
# SISTEMA DE VIDA
# ==============================================================================
func take_damage(amount: int, _applied_knockback_force: Vector2 = Vector2.ZERO) -> void:
	# O boss não sofre knockback algum — o parâmetro é ignorado de propósito,
	# mantido apenas para compatibilidade de assinatura com os outros inimigos.
	if _current_health <= 0:
		return

	_current_health = max(0, _current_health - amount)

	_flash_damage()
	print("Boss recebeu dano! Vida: ", _current_health, "/", MAX_HEALTH)

	_check_phase_transition()

	if _current_health == 0:
		_start_death()

# Verifica se a vida caiu para metade ou menos e ativa a fase 2 (uma única vez)
func _check_phase_transition() -> void:
	if not _is_phase2 and _current_health <= MAX_HEALTH / 2:
		_is_phase2 = true
		print("Boss entrou na FASE 2!")

func _flash_damage() -> void:
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color.RED,   0.1)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.1)

# ==============================================================================
# MORTE
# ==============================================================================
func _start_death() -> void:
	_transition_to(State.DEAD)
	velocity = Vector2.ZERO
	_hitbox_Slash.disabled  = true
	_hitbox_Pierce.disabled = true
	_sprite.play("Death")
	print("Boss morreu!")

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

	# Mantém as hitbox de ataque alinhadas com a direção do sprite
	if _hitbox_Pierce.position.x != 0:
		_hitbox_Pierce.position.x = abs(_hitbox_Pierce.position.x) * _direction
	if _hitbox_Slash.position.x != 0:
		_hitbox_Slash.position.x  = abs(_hitbox_Slash.position.x) * _direction

	# Estados com animação própria controlada pelas funções de ataque/morte
	if _state in [State.ATTACK_MAGIC, State.ATTACK_PIERCE, State.ATTACK_SLASH, State.DEAD]:
		return

	match _state:
		State.IDLE:
			if _sprite.animation != "Idle" or not _sprite.is_playing():
				_sprite.play("Idle")
		State.WALK:
			if _sprite.animation != "Walk" or not _sprite.is_playing():
				_sprite.play("Walk")

func _on_frame_changed() -> void:
	# Ajuste os números de frame conforme a sua animação real
	if _sprite.animation == "Slash_Attack" and _sprite.frame == 3:
		_enable_slash_hitbox()
	elif _sprite.animation == "Pierce_Attack" and _sprite.frame == 2:
		_enable_pierce_hitbox()

# ==============================================================================
# HITBOX — colisão com o player
# ==============================================================================
func _on_hitbox_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player_hurtbox"):
		return
	var player = area.get_parent()
	if not player.has_method("take_damage"):
		return

	if _state == State.ATTACK_SLASH and not _hitbox_Slash.disabled:
		var applied_force := Vector2(KNOCKBACK_FORCE.x * _direction, KNOCKBACK_FORCE.y)
		player.take_damage(SLASH_DAMAGE, applied_force)
	elif _state == State.ATTACK_PIERCE and not _hitbox_Pierce.disabled:
		var applied_force := Vector2(KNOCKBACK_FORCE.x * _direction, KNOCKBACK_FORCE.y)
		player.take_damage(PIERCE_DAMAGE, applied_force)
