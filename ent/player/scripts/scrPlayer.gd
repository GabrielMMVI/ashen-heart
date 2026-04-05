extends CharacterBody2D
@onready var ansprPlayer: AnimatedSprite2D = $ansprPlayer

const SPEED = 100.0
const JUMP_VELOCITY = -300.0

# --- SISTEMA DE ARMAS ---
enum Weapon { SWORD, BOW, STAFF, AXE }

var current_weapon: Weapon = Weapon.SWORD
var facing_right := true

# Mapeamento de arma → animação de ataque
const ATTACK_ANIMATIONS = {
	Weapon.SWORD: "attack_melee",
	Weapon.BOW:   "attack_bow",
	Weapon.STAFF: "attack_magic",
	Weapon.AXE:   "attack_axe"
}

# Mapeamento de arma → nome para exibir no HUD 
const WEAPON_NAMES = {
	Weapon.SWORD: "Espada",
	Weapon.BOW:   "Arco",
	Weapon.STAFF: "Cajado",
	Weapon.AXE:   "Machado"
}

func _switch_weapon(direction: int) -> void:
	if is_attacking:
		return  # Não troca enquanto ataca
	var total = Weapon.size()
	current_weapon = (current_weapon + direction + total) % total
	print("Arma atual: ", WEAPON_NAMES[current_weapon])  # Troque por HUD depois

# --- ATAQUE ---
var is_attacking := false

func _attack_melee() -> void:
	if Input.is_action_just_pressed("attack") and not is_attacking:
		is_attacking = true
		ansprPlayer.flip_h = not facing_right
		var anim = ATTACK_ANIMATIONS[current_weapon]
		ansprPlayer.play(anim)
		await ansprPlayer.animation_finished
		is_attacking = false

# --- LOOP PRINCIPAL ---
func _physics_process(delta: float) -> void:
	# Troca de arma com Q ou scroll
	if Input.is_action_just_pressed("weapon_next"):
		_switch_weapon(1)
	if Input.is_action_just_pressed("weapon_prev"):
		_switch_weapon(-1)

	_attack_melee()

	# Gravidade
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Pulo
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movimento horizontal
	var direction := Input.get_axis("left", "right")
	if is_attacking:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	elif direction:
		velocity.x = direction * SPEED
		facing_right = direction > 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# Animações
	if not is_attacking:
		ansprPlayer.flip_h = not facing_right
		if is_on_floor():
			if direction != 0:
				ansprPlayer.play("walk")
			else:
				ansprPlayer.play("idle")
		else:
			if velocity.y < 0:
				ansprPlayer.play("jump")
			else:
				ansprPlayer.play("fall")

	move_and_slide()
