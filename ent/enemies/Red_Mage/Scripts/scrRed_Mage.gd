extends CharacterBody2D

# ==============================================================================
# CONSTANTES
# ==============================================================================
const SPEED_WALK        := 30.0    # Velocidade de patrulha e aproximação
const MAGIC_SPEED       := 60.0    # Velocidade do projétil mágico
const MAX_HEALTH        := 50

# ── Ranges de comportamento ────────────────────────────────────────────────────
#
#   |← PREFERRED_RANGE →|← DETECTION_RANGE →|
#   [===ATIRA PARADO======[===ALERTA/IDLE=======]
#
#   ≤ PREFERRED_RANGE    → faixa ideal → para e atira
#   > PREFERRED_RANGE    → se aproxima caminhando
#   > DISENGAGE_RANGE    → player fugiu → volta ao IDLE
#
const DETECTION_RANGE   := 250.0   # Até onde "enxerga" o player
const PREFERRED_RANGE   := 150.0   # Distância ideal para lançar magia
const DISENGAGE_RANGE   := 380.0   # Se o player fugir além disso → IDLE

const ALERT_DURATION    := 0.6     # Pausa ao avistar o player
const ATTACK_COOLDOWN   := 0.5     # Pausa entre ataques consecutivos

# ==============================================================================
# ESTADOS DO INIMIGO
# Diagrama de transições:
#
#   IDLE ──(player entra em DETECTION_RANGE)──► ALERTED
#   ALERTED ──(timer esgota)──► COMBAT
#   COMBAT ──(dist > DISENGAGE_RANGE)──► IDLE
#   COMBAT ──(dist ≤ PREFERRED_RANGE)──► para e atira
#   COMBAT ──(dist > PREFERRED_RANGE)──► caminha em direção ao player
#   qualquer ──(take_damage com knockback)──► KNOCKBACK
#   KNOCKBACK ──(timer esgota)──► COMBAT ou IDLE
# ==============================================================================
enum State { IDLE, ALERTED, COMBAT, KNOCKBACK }

# ==============================================================================
# EXPORTS E NÓS REFERENCIADOS
# ==============================================================================
@export var knockback_resistance: float = 10.0

@export var magic_ball_scene: PackedScene = preload("res://ent/projectiles/magic_ball/mage_magic_ball.tscn")
@onready var _sprite:       AnimatedSprite2D = $ansprRed_Mage
@onready var _shoot_point:  Marker2D         = $mkShoot

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================
var _direction:      int   = -1
var _player:         Node2D = null
var _current_health: int   = MAX_HEALTH
var _state:          State = State.IDLE
var _alert_timer:    float = 0.0
var _is_attacking:          bool  = false  # true enquanto a animação de ataque roda
var _attack_cooldown_timer: float = 0.0    # tempo restante antes do próximo ataque

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
		State.IDLE:      _process_idle()
		State.ALERTED:   _process_alerted(delta)
		State.COMBAT:    _process_combat(delta)
		State.KNOCKBACK: pass   # Controlado pelo timer de knockback

# ── IDLE ──────────────────────────────────────────────────────────────────────
# Patrulha vagarosamente. Inverte direção ao bater na parede.
# Assim que o player entra no range de detecção, entra em alerta.
func _process_idle() -> void:
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

# ── ALERTED ───────────────────────────────────────────────────────────────────
# Pausa dramática ao avistar o player antes de entrar em combate.
func _process_alerted(delta: float) -> void:
	velocity.x = 0
	_alert_timer -= delta
	if _alert_timer <= 0.0:
		_transition_to(State.COMBAT)

# ── COMBAT ────────────────────────────────────────────────────────────────────
# O mago sempre olha para o player e avalia a distância a cada frame:
#   • Player dentro da faixa ideal → para e lança magia (com cooldown entre ataques)
#   • Player além da faixa ideal   → cancela ataque e caminha em direção a ele
#   • Player fugiu longe demais    → desengaja e volta ao IDLE
func _process_combat(delta: float) -> void:
	if not is_instance_valid(_player):
		_transition_to(State.IDLE)
		return

	# Tick do cooldown entre ataques
	_attack_cooldown_timer = max(0.0, _attack_cooldown_timer - delta)

	var dist := global_position.distance_to(_player.global_position)

	# Player fugiu longe demais → desengaja (costas para o player)
	if dist > DISENGAGE_RANGE:
		_is_attacking = false
		_direction = -sign(_player.global_position.x - global_position.x)
		_transition_to(State.IDLE)
		return

	# Sempre olha para o player no estado de combate
	_direction = sign(_player.global_position.x - global_position.x)

	# Player saiu da faixa ideal → cancela ataque imediatamente e se aproxima
	if dist > PREFERRED_RANGE:
		_is_attacking = false
		velocity.x = _direction * SPEED_WALK
	else:
		# Faixa ideal: para no lugar e atira (respeitando o cooldown)
		velocity.x = 0
		_try_start_attack()

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
	print("Mago Vermelho recebeu dano! Vida: ", _current_health, "/", MAX_HEALTH)

	if _current_health == 0:
		_die()

func _on_knockback_ended() -> void:
	if is_instance_valid(_player):
		_transition_to(State.COMBAT)
	else:
		_transition_to(State.IDLE)

func _die() -> void:
	print("Mago Vermelho morreu!")
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
	if _is_attacking or _attack_cooldown_timer > 0.0:
		return
	_is_attacking = true
	_sprite.play("attack")

# ==============================================================================
# ANIMAÇÕES
# ==============================================================================
func _update_animation() -> void:
	_sprite.flip_h = (_direction < 0)

	if _is_attacking or _state == State.KNOCKBACK:
		return

	match _state:
		State.IDLE:
			# Patrulhando: retoma "walk" sempre que não estiver tocando corretamente
			if _sprite.animation != "walk" or not _sprite.is_playing():
				_sprite.play("walk")
		State.ALERTED:
			# Pausa dramática ao avistar o player
			if _sprite.animation != "idle" or not _sprite.is_playing():
				_sprite.play("idle")
		State.COMBAT:
			if velocity.x != 0.0:
				# Se aproximando do player
				if _sprite.animation != "walk" or not _sprite.is_playing():
					_sprite.play("walk")
			else:
				# Parado na faixa ideal, pronto para lançar magia
				if _sprite.animation != "idle" or not _sprite.is_playing():
					_sprite.play("idle")

func _on_frame_changed() -> void:
	# Instancia a magia no frame exato. Ajuste o "3" para o frame correto.
	if _sprite.animation == "attack" and _sprite.frame == 3:
		_enemy_shoot_magic()

func _on_animation_finished() -> void:
	if _sprite.animation == "attack":
		_is_attacking = false
		# Inicia o cooldown antes do próximo ataque para uma transição mais natural
		_attack_cooldown_timer = ATTACK_COOLDOWN

# ==============================================================================
# PROJÉTIL
# ==============================================================================
func _enemy_shoot_magic() -> void:
	if not magic_ball_scene:
		push_error("Magic Ball scene não atribuída no Red_Mage!")
		return

	var enemyball = magic_ball_scene.instantiate()
	get_tree().current_scene.add_child(enemyball)

	var start_pos: Vector2 = _shoot_point.global_position if _shoot_point else global_position
	enemyball.global_position = start_pos

	if is_instance_valid(_player) and enemyball.has_method("fire"):
		# A magia viaja em linha reta apontando direto para o alvo.
		var direction_to_player := start_pos.direction_to(_player.global_position)
		enemyball.fire(direction_to_player)
		print("ENEMYSHOT")
