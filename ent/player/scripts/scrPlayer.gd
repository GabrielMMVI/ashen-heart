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
const ARROW_SPEED_X := 450

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
@export var player_arrow: PackedScene = preload("res://ent/player/projectiles/basic_arrow/player_arrow_scene.tscn")
@export var player_sword_slash: PackedScene = preload("res://ent/player/projectiles/Sword_Attack/Sword_Attack.tscn")
@export var player_axe_slash: PackedScene = preload("res://ent/player/projectiles/Axe_Attack/Axe_Slash.tscn")

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
	elif _current_weapon == Weapon.BOW:
		_shoot_arrow()
	elif _current_weapon == Weapon.SWORD:
		_attack_sword()
	elif _current_weapon == Weapon.AXE:
		_attack_axe()

	_sprite.play(ATTACK_ANIMATIONS[_current_weapon])
	await _sprite.animation_finished
	
	if _current_weapon == Weapon.AXE:
		await get_tree().create_timer(0.6).timeout
		
	_is_attacking = false
	
func _attack_axe() -> void:
	if not player_axe_slash:
		push_error("Cena do machado não associada no PLayer!")
		return
		
	var playeraxe = player_axe_slash.instantiate()
	add_child(playeraxe)
	if playeraxe.has_method("swing"):
		playeraxe.swing(_facing_right)
	
	print("PLAYER: AXE")

func _attack_sword() -> void:
	if not player_sword_slash:
		push_error("Cena da espada não associada no PLayer!")
		return
		
	var playersword = player_sword_slash.instantiate()
	add_child(playersword)
	if playersword.has_method("swing"):
		playersword.swing(_facing_right)
	print("PLAYER: SWORD ATTACK")

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
	print("PLAYER: MAGIC SHOT")

func _shoot_arrow() -> void:
	if not player_arrow:
		push_error("Não encontrada cena da flecha associada ao player")
		return
		
	var playerarrow = player_arrow.instantiate()
	get_tree().current_scene.add_child(playerarrow)
	
	var start_pos = global_position
	playerarrow.global_position = start_pos
	
	var mouse_pos = get_global_mouse_position()
	
	# Calcula a física do lançamento oblíquo do player até o mouse
	var calculated_velocity = _calculate_trajectory(start_pos, mouse_pos)
	
	if playerarrow.has_method("fire"):
		playerarrow.fire(calculated_velocity)
		
	print("PLAYER: ARROW SHOT")

func _calculate_trajectory(start: Vector2, target: Vector2) -> Vector2:
	# Puxa a gravidade global do Godot (a mesma que puxa a flecha para baixo)
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	var displacement = target - start
	
	# Tempo de voo baseado na distância X até o mouse
	var time_of_flight = abs(displacement.x) / ARROW_SPEED_X
	if time_of_flight <= 0.01:
		time_of_flight = 0.01
		
	# Vetor X (Esquerda/Direita)
	var velocity_x = ARROW_SPEED_X * sign(displacement.x)
	
	# Vetor Y (Força do arco para cima necessária para cair exatamente no mouse)
	var velocity_y = (displacement.y - 0.5 * gravity * time_of_flight * time_of_flight) / time_of_flight
	
	return Vector2(velocity_x, velocity_y)


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
	
	if _is_attacking and _current_weapon == Weapon.AXE:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		return
		
	var direction := Input.get_axis("left", "right")

	if direction == 0:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	else:
		velocity.x = direction * SPEED
		_facing_right = direction > 0
		
func _handle_dash() -> void:
	var mouse_pos = get_global_mouse_position()
	var dash_direction = global_position.direction_to(mouse_pos)
	
	if Input.is_action_just_pressed("dash"):
		if dash_direction == 0:
			velocity.x = move_toward(velocity.x,0,SPEED*10)
		else:
			velocity.x = dash_direction*SPEED*10
			_facing_right = dash_direction > 0

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
