extends CharacterBody2D

# -- Constates -----------------------------------------------------------------
const MAX_HEALTH := 870
const WALK_SPEED := 40
const JUMP_VELOCITY := -500
const STOMP_COOLDOWN := 15
const KNOCKBACK_FORCE := Vector2(400.0, -50)
# -- Danos
const PIERCE_DAMAGE := 80
const SLASH_DAMAGE := 60
# -- Ranges
const SLASH_RANGE := 40
const PIERCE_RANGE := 60
const BALL_RANGE := 160
const DETECTION_RANGE := 120

# -- Estados -------------------------------------------------------------------
enum State{IDLE, WALK, ATTACK_MAGIC, ATTACK_PIERCE, ATTACK_SLASH, DEAD}

@export var knockback_resistance: float = 500

@onready var _sprite: AnimatedSprite2D = $ansprMaximos 
@onready var _hurtbox: CollisionShape2D = $colHurtbox
@onready var _hitbox_Slash: CollisionShape2D = $aHitBox/aHitbox_Slash
@onready var _hitbox_Pierce: CollisionShape2D = $aHitBox/aHitbox_Pierce

# -- Estado interno ------------------------------------------------------------
var _direction      := -1
var _player:  Node2D = null
var _current_health := MAX_HEALTH
var _state          := State.IDLE

# -- Ready ---------------------------------------------------------------------
func _ready() -> void:
	_current_health = MAX_HEALTH
	# Falta fazer as conexões das hitbox

# -- Loop Principal ------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_handle_gravity(delta)
	_tick_state(delta)
	_update_animation()
	move_and_slide()


# -- Máquina de estados --------------------------------------------------------
func _tick_state(delta: float) -> void:
	match _state:
		State.IDLE: _process_idle()
		State.WALK: _process_walk()
		State.ATTACK_MAGIC: _attack_magic()
		State.ATTACK_PIERCE: _attack_pierce()
		State.ATTACK_SLASH: _attack_slash()
		State.DEAD: _die()
		
# IDLE
func _process_idle() -> void:
	velocity.x = 0
	if not is_instance_valid(_player):
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist <= DETECTION_RANGE:
		_transition_to(State.ATTACK_SLASH)
		
# WALK
func _process_walk() -> void:
	if is_on_wall():
		_direction *= -1
	velocity.x = _direction * 50.0
	# Coloquei assim só pra ele andar

# ATTACK_MAGIC
func _attack_magic() -> void:
		print("Ainda a ser implementado")
	# Os ataques não ficarão nessa seção de estados, coloquei aqui somente por hora mesmo para deixar detalhado o que falta

# ATTACK_PIERCE
func _attack_pierce() -> void:
	print("Ainda a ser implementado")

# ATTACK_SLASH
func _attack_slash() -> void:
	print("Ainda a ser implementado")
	
# DEAD
func _die() -> void:
	print("Ainda a ser implementado")
# -- Física --------------------------------------------------------------------
func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
		
# -- Atualiza animação/Estados -------------------------------------------------
func _update_animation() -> void:
	print("Ainda a implementar")

func _transition_to(new_state: State) -> void:
	_state = new_state
