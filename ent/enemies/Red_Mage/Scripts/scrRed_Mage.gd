extends CharacterBody2D

# ==============================================================================
# CONSTANTES
# ==============================================================================
const SPEED := 30.0 # Velocidade reduzida em relação ao Ranger
const ATTACK_RANGE := 150.0 # Alcance reduzido
const MAGIC_SPEED := 250.0 # Velocidade do projétil mágico

# ==============================================================================
# EXPORTS E NÓS REFERENCIADOS
# ==============================================================================
@export var magic_ball_scene: PackedScene = preload("res://ent/projectiles/magic_ball/magic_ball.tscn")

@onready var _sprite: AnimatedSprite2D = $ansprRed_Mage
@onready var _shoot_point: Marker2D = $mkShoot

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================
var _direction := -1
var _is_attacking := false
var _player: Node2D = null

# ==============================================================================
# PRONTO
# ==============================================================================
func _ready() -> void:
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.frame_changed.connect(_on_frame_changed)

# ==============================================================================
# LOOP PRINCIPAL
# ==============================================================================
func _physics_process(delta: float) -> void:
	_handle_gravity(delta)
	_find_player()
	
	if not _is_attacking:
		_try_attack()
		_handle_movement()
	else:
		velocity.x = 0
		# Atualiza a mira continuamente enquanto ataca
		if _player != null and global_position.distance_to(_player.global_position) <= ATTACK_RANGE:
			_direction = 1 if _player.global_position.x > global_position.x else -1
	
	_update_animation()
	move_and_slide()

# ==============================================================================
# FÍSICA E MOVIMENTO (PATRULHA LENTA)
# ==============================================================================
func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

func _handle_movement() -> void:
	if is_on_wall():
		_direction *= -1
	velocity.x = _direction * SPEED

# ==============================================================================
# DETECÇÃO DO PLAYER E LÓGICA DE ATAQUE
# ==============================================================================
func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]

func _try_attack() -> void:
	if _player == null:
		return
	
	if global_position.distance_to(_player.global_position) <= ATTACK_RANGE:
		_direction = 1 if _player.global_position.x > global_position.x else -1
		start_attack()

func start_attack() -> void:
	if _is_attacking:
		return
	_is_attacking = true
	velocity.x = 0
	_sprite.play("attack")

# ==============================================================================
# ANIMAÇÕES E EVENTOS
# ==============================================================================
func _update_animation() -> void:
	_sprite.flip_h = _direction < 0
	
	if _is_attacking:
		return
	
	if is_on_floor():
		_sprite.play("walk")

func _on_frame_changed() -> void:
	# Instancia a magia no frame exato (Ajuste o "2" conforme a sua animação)
	if _sprite.animation == "attack" and _sprite.frame == 3:
		_shoot_magic()

func _on_animation_finished() -> void:
	if _sprite.animation == "attack":
		if _player != null and global_position.distance_to(_player.global_position) <= ATTACK_RANGE:
			_direction = 1 if _player.global_position.x > global_position.x else -1
			_sprite.play("attack")
		else:
			_is_attacking = false

# ==============================================================================
# INSTANCIAÇÃO DO PROJÉTIL
# ==============================================================================
func _shoot_magic() -> void:
	if not magic_ball_scene:
		push_error("Magic Ball scene not assigned in Red_Mage!")
		return
		
	var ball = magic_ball_scene.instantiate()
	get_tree().current_scene.add_child(ball)
	
	var start_pos = _shoot_point.global_position if _shoot_point else global_position
	ball.global_position = start_pos
	
	if _player != null and ball.has_method("fire"):
		# Diferente do arco (que exige cálculo de gravidade), 
		# a magia viaja em linha reta apontando direto para o alvo.
		var direction_to_player = start_pos.direction_to(_player.global_position)
		ball.fire(direction_to_player * MAGIC_SPEED)
