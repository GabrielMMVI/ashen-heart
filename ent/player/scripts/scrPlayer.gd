extends CharacterBody2D

# ==============================================================================
# SINAIS
# ==============================================================================
signal weapon_changed(weapon_name: String)
signal health_changed(current_health: int, max_health: int)

# ==============================================================================
# CONSTANTES
# ==============================================================================
const SPEED := 100.0
const JUMP_VELOCITY := -260.0
const PLAYER_GRAVITY := 550.0
const MAX_HEALTH := 100
const MELEE_DAMAGE := 20

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
@export var player_magic_ball: PackedScene = preload("res://ent/player/projectiles/magic_ball/player_magic_ball.tscn")

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================
var _current_weapon: Weapon = Weapon.SWORD
var _current_health := MAX_HEALTH
var _is_attacking := false
var _is_switching := false
var _facing_right := true
var _is_invincible := false
var _start_position := Vector2.ZERO  # <- NOVO: salva posição inicial

# ==============================================================================
# PRONTO
# ==============================================================================	
func _ready() -> void:
	add_to_group("player")
	_start_position = global_position  # <- NOVO: guarda onde o player começa
	_current_health = MAX_HEALTH
	call_deferred("emit_signal", "weapon_changed", WEAPON_NAMES[_current_weapon])
	call_deferred("emit_signal", "health_changed", _current_health, MAX_HEALTH)

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


# ==============================================================================
# SISTEMA DE VIDA
# ==============================================================================
func take_damage(amount: int) -> void:
	if _current_health <= 0 or _is_invincible:
		return

	_current_health -= amount
	_current_health = max(0, _current_health)

	print("Dano recebido! Vida atual: ", _current_health, "/", MAX_HEALTH)
	health_changed.emit(_current_health, MAX_HEALTH)

	_flash_damage()

	_is_invincible = true
	await get_tree().create_timer(0.8).timeout
	_is_invincible = false

	if _current_health == 0:
		_die()

func _die() -> void:
	print("Player Morreu!")
	set_physics_process(false)

	# Pequena pausa antes de respawnar
	await get_tree().create_timer(1.0).timeout

	# Reseta vida e posição
	_current_health = MAX_HEALTH
	health_changed.emit(_current_health, MAX_HEALTH)
	global_position = _start_position
	velocity = Vector2.ZERO
	_is_invincible = false

	# Reativa o movimento
	set_physics_process(true)

func _flash_damage() -> void:
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.1)

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
	
	# Se a arma atual for o cajado, instanciamos a magia
	if _current_weapon == Weapon.STAFF:
		_shoot_magic()

	_sprite.play(ATTACK_ANIMATIONS[_current_weapon])
	await _sprite.animation_finished
	_is_attacking = false

func _shoot_magic() -> void:
	if not player_magic_ball:
		push_error("Cena da bolinha mágica não associada no Player!")
		return
		
	var playerball = player_magic_ball.instantiate()
	get_tree().current_scene.add_child(playerball)
	playerball.global_position = global_position
	
	# Coleta a posição exata do mouse no mundo do jogo
	var mouse_pos = get_global_mouse_position()
	
	# Calcula o vetor direção normalizado do player até o mouse
	var direction = global_position.direction_to(mouse_pos)
	
	# Passa apenas a direção para a bolinha
	playerball.fire(direction)
	print("PLAYERSHOT")

# ==============================================================================
# FÍSICA E MOVIMENTO
# ==============================================================================
func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += PLAYER_GRAVITY * delta

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	if Input.is_action_just_released("jump") and velocity.y < 0:
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
