extends CharacterBody2D

# ==============================================================================
# SINAIS
# ==============================================================================
signal weapon_changed(weapon_name: String)
# Novo sinal para a vida, enviando a vida atual e a máxima
signal health_changed(current_health: int, max_health: int)

# ==============================================================================
# CONSTANTES
# ==============================================================================
const SPEED := 100.0
# Velocidade inicial menor = personagem sobe mais devagar
const JUMP_VELOCITY := -260.0 
# Gravidade exclusiva do player (reduzida para compensar a perda de força e manter a altura)
const PLAYER_GRAVITY := 550.0
const MAX_HEALTH := 100

# ==============================================================================
# ENUMS E MAPEAMENTOS
# ==============================================================================
enum Weapon { SWORD, BOW, STAFF, AXE }
const ATTACK_ANIMATIONS: Dictionary = {
	Weapon.SWORD: "attack_melee",
	Weapon.BOW:   "attack_bow",
	Weapon.STAFF: "attack_magic",
	Weapon.AXE:   "attack_axe",
}

const WEAPON_NAMES: Dictionary = {
	Weapon.SWORD: "Espada",
	Weapon.BOW:   "Arco",
	Weapon.STAFF: "Cajado",
	Weapon.AXE:   "Machado",
}

# ==============================================================================
# NÓS REFERENCIADOS
# ==============================================================================
@onready var _sprite: AnimatedSprite2D = $ansprPlayer

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================
var _current_weapon: Weapon = Weapon.SWORD
var _current_health := MAX_HEALTH
var _is_attacking := false
var _is_switching := false
var _facing_right := true

# ==============================================================================
# LOOP PRINCIPAL
# ==============================================================================
func _physics_process(delta: float) -> void:
	_handle_weapon_switch()
	_handle_attack()
	_handle_gravity(delta)
	_handle_jump()
	_handle_movement()
	_update_animation()
	move_and_slide()

func _ready() -> void:
	_current_health = MAX_HEALTH
	call_deferred("emit_signal", "weapon_changed", WEAPON_NAMES[_current_weapon])
	# Emite a vida inicial para a HUD preencher a barra logo que o jogo abre
	call_deferred("emit_signal", "health_changed", _current_health, MAX_HEALTH)
	
# ==============================================================================
# SISTEMA DE VIDA
# ==============================================================================
func take_damage(amount: int) -> void:
	if _current_health <= 0:
		return 
		
	_current_health -= amount
	_current_health = max(0, _current_health) 
	
	print("Dano recebido! Vida atual: ", _current_health, "/", MAX_HEALTH)
	
	# Dispara o sinal avisando a HUD
	health_changed.emit(_current_health, MAX_HEALTH)
	
	if _current_health == 0:
		_die()

func _die() -> void:
	print("Player Morreu!")
	set_physics_process(false) 

# ==============================================================================
# SISTEMA DE ARMAS
# ==============================================================================
func _handle_weapon_switch() -> void:
	if Input.is_action_just_pressed("switch"):
		_switch_weapon(1)

func _switch_weapon(direction: int) -> void:
	if _is_attacking or _is_switching:
		return
		
	_is_switching = true
	
	var total: int = Weapon.size()
	_current_weapon = (_current_weapon + direction + total) % total
	var weapon_name = WEAPON_NAMES[_current_weapon]
	
	weapon_changed.emit(weapon_name)
	
	_sprite.play("switch_weapon")
	await _sprite.animation_finished
	
	_is_switching = false

# ==============================================================================
# SISTEMA DE ATAQUE
# ==============================================================================
func _handle_attack() -> void:
	if Input.is_action_just_pressed("attack") and not _is_attacking and not _is_switching:
		_perform_attack()

func _perform_attack() -> void:
	_is_attacking = true
	
	# TESTE: Tirando 1 de vida do próprio player a cada ataque
	take_damage(1)
	
	_sprite.play(ATTACK_ANIMATIONS[_current_weapon])
	await _sprite.animation_finished
	_is_attacking = false

# ==============================================================================
# FÍSICA E MOVIMENTO
# ==============================================================================
func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		# Substitui a gravidade global (get_gravity) pela gravidade própria
		velocity.y += PLAYER_GRAVITY * delta

func _handle_jump() -> void:
	# Pulo inicial: aplica a força total quando o botão é pressionado no chão
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	# Pulo dinâmico: se o jogador soltar o botão ("just_released") 
	# ENQUANTO o personagem estiver subindo (velocity.y < 0)
	if Input.is_action_just_released("jump") and velocity.y < 0:
		# Corta a velocidade vertical pela metade (reduz a altura)
		velocity.y *= 0.5

func _handle_movement() -> void:
	var direction := Input.get_axis("left", "right")

	if direction == 0:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	else:
		velocity.x = direction * SPEED
		_facing_right = direction > 0

# ==============================================================================
# ANIMAÇÕES
# ==============================================================================
func _update_animation() -> void:
	_sprite.flip_h = not _facing_right

	if _is_attacking or _is_switching:
		return

	if is_on_floor():
		_play_grounded_animation()
	else:
		_play_airborne_animation()

func _play_grounded_animation() -> void:
	var direction := Input.get_axis("left", "right")
	if direction != 0:
		_sprite.play("walk")
	else:
		_sprite.play("idle")

func _play_airborne_animation() -> void:
	if velocity.y < 0:
		_sprite.play("jump")
	else:
		_sprite.play("fall")
