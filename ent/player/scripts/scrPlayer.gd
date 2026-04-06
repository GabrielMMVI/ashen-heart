extends CharacterBody2D

# ==============================================================================
# CONSTANTES
# ==============================================================================
const SPEED := 100.0
const JUMP_VELOCITY := -300.0

# ==============================================================================
# ENUMS E MAPEAMENTOS
# ==============================================================================
enum Weapon { SWORD, BOW, STAFF, AXE }
#tetetet
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
var _is_attacking := false
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

# ==============================================================================
# SISTEMA DE ARMAS
# ==============================================================================
func _handle_weapon_switch() -> void:
	if Input.is_action_just_pressed("weapon_next"):
		_switch_weapon(1)
	elif Input.is_action_just_pressed("weapon_prev"):
		_switch_weapon(-1)

func _switch_weapon(direction: int) -> void:
	if _is_attacking:
		return

	var total: int = Weapon.size()
	_current_weapon = (_current_weapon + direction + total) % total
	print("Arma atual: ", WEAPON_NAMES[_current_weapon]) # TODO: substituir por HUD

# ==============================================================================
# SISTEMA DE ATAQUE
# ==============================================================================
func _handle_attack() -> void:
	if Input.is_action_just_pressed("attack") and not _is_attacking:
		_perform_attack()

func _perform_attack() -> void:
	_is_attacking = true
	_sprite.flip_h = not _facing_right
	_sprite.play(ATTACK_ANIMATIONS[_current_weapon])
	await _sprite.animation_finished
	_is_attacking = false

# ==============================================================================
# FÍSICA E MOVIMENTO
# ==============================================================================
func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

func _handle_movement() -> void:
	var direction := Input.get_axis("left", "right")

	if _is_attacking or direction == 0:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		return

	velocity.x = direction * SPEED
	_facing_right = direction > 0

# ==============================================================================
# ANIMAÇÕES
# ==============================================================================
func _update_animation() -> void:
	if _is_attacking:
		return

	_sprite.flip_h = not _facing_right

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
