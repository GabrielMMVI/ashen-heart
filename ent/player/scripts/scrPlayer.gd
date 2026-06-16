extends CharacterBody2D

# ==============================================================================
# SINAIS
# ==============================================================================
signal weapon_changed(weapon_name: String)
signal health_changed(current_health: int, max_health: int)

# ==============================================================================
# CONSTANTES
# ==============================================================================
const SPEED          := 100.0
const ACCELERATION   := 800.0    # px/s² — rampa de subida até a velocidade máxima
const FRICTION       := 600.0    # px/s² — rampa de frenagem até parar
const JUMP_VELOCITY  := -250.0
const PLAYER_GRAVITY := 550.0
const MAX_HEALTH     := 100
const MELEE_DAMAGE   := 20
const ARROW_SPEED_X  := 450.0

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
@export var knockback_resistance: float = 20.0

@onready var _sprite: AnimatedSprite2D = $ansprPlayer

@export var player_magic_ball:   PackedScene = preload("res://ent/player/projectiles/magic_ball/player_magic_ball.tscn")
@export var player_arrow:        PackedScene = preload("res://ent/player/projectiles/basic_arrow/player_arrow_scene.tscn")
@export var player_sword_slash:  PackedScene = preload("res://ent/player/projectiles/Sword_Attack/Sword_Attack.tscn")
@export var player_axe_slash:    PackedScene = preload("res://ent/player/projectiles/Axe_Attack/Axe_Slash.tscn")

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================
var _current_weapon:  Weapon = Weapon.SWORD
var _current_health:  int    = MAX_HEALTH
var _facing_right:    bool   = true
var _is_attacking:    bool   = false
var _is_switching:    bool   = false
var _is_knocked_back: bool   = false
var _is_invincible:   bool   = false
var _start_position:  Vector2 = Vector2.ZERO

# ==============================================================================
# PRONTO
# ==============================================================================
func _ready() -> void:
	add_to_group("player")
	_start_position = global_position
	_current_health = MAX_HEALTH
	call_deferred("emit_signal", "weapon_changed", WEAPON_NAMES[_current_weapon])
	call_deferred("emit_signal", "health_changed", _current_health, MAX_HEALTH)

# ==============================================================================
# LOOP PRINCIPAL
# ==============================================================================
func _physics_process(delta: float) -> void:
	if _is_knocked_back:
		move_and_slide()
		return

	_handle_weapon_switch()
	_handle_attack()
	_handle_gravity(delta)
	_handle_jump()
	_handle_movement(delta)
	_update_animation()
	move_and_slide()

# ==============================================================================
# SISTEMA DE VIDA
# ==============================================================================
func take_damage(amount: int, applied_knockback: Vector2 = Vector2.ZERO) -> void:
	if _current_health <= 0 or _is_invincible:
		return

	_current_health = max(0, _current_health - amount)

	print("Dano recebido! Vida atual: ", _current_health, "/", MAX_HEALTH)
	health_changed.emit(_current_health, MAX_HEALTH)

	if applied_knockback != Vector2.ZERO:
		var kx: float = max(0.0, abs(applied_knockback.x) - knockback_resistance)
		var ky: float = max(0.0, abs(applied_knockback.y) - knockback_resistance)
		velocity.x = kx * sign(applied_knockback.x)
		velocity.y = ky * sign(applied_knockback.y)

		if kx > 0.0 or ky > 0.0:
			_is_knocked_back = true
			get_tree().create_timer(0.3).timeout.connect(func(): _is_knocked_back = false)

	_flash_damage()

	_is_invincible = true
	await get_tree().create_timer(0.8).timeout
	_is_invincible = false

	if _current_health == 0:
		_die()

func _die() -> void:
	print("Player Morreu!")
	set_physics_process(false)

	await get_tree().create_timer(1.0).timeout

	_current_health = MAX_HEALTH
	health_changed.emit(_current_health, MAX_HEALTH)
	global_position = _start_position
	velocity        = Vector2.ZERO
	_is_invincible  = false

	set_physics_process(true)

func _flash_damage() -> void:
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color.RED,   0.1)
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

	weapon_changed.emit(WEAPON_NAMES[_current_weapon])
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

	match _current_weapon:
		Weapon.STAFF: _shoot_magic()
		Weapon.BOW:   _shoot_arrow()
		Weapon.SWORD: _attack_sword()
		Weapon.AXE:   _attack_axe()

	_sprite.play(ATTACK_ANIMATIONS[_current_weapon])
	await _sprite.animation_finished

	if _current_weapon == Weapon.AXE:
		await get_tree().create_timer(0.6).timeout

	_is_attacking = false

func _attack_sword() -> void:
	if not player_sword_slash:
		push_error("Cena da espada não associada no Player!")
		return

	var slash = player_sword_slash.instantiate()
	add_child(slash)
	if slash.has_method("swing"):
		slash.swing(_facing_right)
	print("PLAYER: SWORD ATTACK")

func _attack_axe() -> void:
	if not player_axe_slash:
		push_error("Cena do machado não associada no Player!")
		return

	var slash = player_axe_slash.instantiate()
	add_child(slash)
	if slash.has_method("swing"):
		slash.swing(_facing_right)
	print("PLAYER: AXE")

func _shoot_magic() -> void:
	if not player_magic_ball:
		push_error("Cena da bolinha mágica não associada no Player!")
		return

	var ball = player_magic_ball.instantiate()
	get_tree().current_scene.add_child(ball)
	ball.global_position = global_position
	ball.fire(global_position.direction_to(get_global_mouse_position()))
	print("PLAYER: MAGIC SHOT")

func _shoot_arrow() -> void:
	if not player_arrow:
		push_error("Cena da flecha não associada no Player!")
		return

	var arrow = player_arrow.instantiate()
	get_tree().current_scene.add_child(arrow)
	arrow.global_position = global_position

	if arrow.has_method("fire"):
		arrow.fire(_calculate_trajectory(global_position, get_global_mouse_position()))
	print("PLAYER: ARROW SHOT")

func _calculate_trajectory(start: Vector2, target: Vector2) -> Vector2:
	var gravity: float        = ProjectSettings.get_setting("physics/2d/default_gravity")
	var displacement: Vector2 = target - start
	var time_of_flight: float = max(0.01, abs(displacement.x) / ARROW_SPEED_X)
	var vel_x: float = ARROW_SPEED_X * sign(displacement.x)
	var vel_y: float = (displacement.y - 0.5 * gravity * time_of_flight * time_of_flight) / time_of_flight
	return Vector2(vel_x, vel_y)

# ==============================================================================
# FÍSICA
# ==============================================================================
func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += PLAYER_GRAVITY * delta

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= 0.5

func _handle_movement(delta: float) -> void:
	if _is_attacking and _current_weapon == Weapon.AXE:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		return

	var direction := Input.get_axis("left", "right")
	if direction == 0:
		# Sem input → desacelera suavemente com atrito
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	else:
		# Com input → acelera suavemente até SPEED
		velocity.x    = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)
		_facing_right = direction > 0

func _handle_dash() -> void:
	var dash_direction := global_position.direction_to(get_global_mouse_position())

	if Input.is_action_just_pressed("dash"):
		if dash_direction == Vector2.ZERO:
			velocity.x = move_toward(velocity.x, 0, SPEED * 10)
		else:
			velocity.x    = dash_direction.x * SPEED * 10
			_facing_right = dash_direction.x > 0

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
	if Input.get_axis("left", "right") != 0:
		_sprite.play("walk")
	else:
		_sprite.play("idle")

func _play_airborne_animation() -> void:
	if velocity.y < 0:
		_sprite.play("jump")
	else:
		_sprite.play("fall")
