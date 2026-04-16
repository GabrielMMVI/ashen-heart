extends CharacterBody2D

# ==============================================================================
# CONSTANTES
# ==============================================================================
const SPEED := 50.0
const ARROW_SPEED_X := 350.0 # Define o quão rápido a flecha viaja horizontalmente
const ATTACK_RANGE := 250.0 

# ==============================================================================
# NÓS REFERENCIADOS & EXPORTS
# ==============================================================================
@export var arrow_scene: PackedScene = preload("res://ent/projectiles/basic_Arrow/arrow_scene.tscn")
@onready var _sprite: AnimatedSprite2D = $ansprRed_Ranger
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
		velocity.x = 0 # Garante que ele fique cravado no chão ao atacar
	
	_update_animation()
	move_and_slide()

# ==============================================================================
# FÍSICA E MOVIMENTO (PATRULHA SIMPLES)
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
	
	var distance := global_position.distance_to(_player.global_position)
	
	if distance <= ATTACK_RANGE:
		_direction = 1 if _player.global_position.x > global_position.x else -1
		start_attack()

func start_attack() -> void:
	if _is_attacking:
		return
	_is_attacking = true
	velocity.x = 0
	_sprite.play("attack")

# ==============================================================================
# ANIMAÇÕES E EVENTOS DE FRAME
# ==============================================================================
func _update_animation() -> void:
	_sprite.flip_h = _direction < 0
	
	if _is_attacking:
		return
	
	if is_on_floor():
		_sprite.play("walk")

func _on_frame_changed() -> void:
	# Instancia a flecha no momento em que o arco é solto.
	# Mude o "2" para o número do frame exato em que a flecha deve sair.
	if _sprite.animation == "attack" and _sprite.frame == 5:
		_shoot_arrow()

func _on_animation_finished() -> void:
	if _sprite.animation == "attack":
		# Ao fim da animação, checa se deve continuar atacando
		if _player != null and global_position.distance_to(_player.global_position) <= ATTACK_RANGE:
			_direction = 1 if _player.global_position.x > global_position.x else -1
			_sprite.play("attack") # Loopa o ataque
		else:
			_is_attacking = false # Sai do estado de ataque e volta a andar

# ==============================================================================
# INSTANCIAÇÃO DO PROJÉTIL
# ==============================================================================
func _shoot_arrow() -> void:
	if not arrow_scene:
		push_error("Arrow scene not assigned in Red_Ranger!")
		return
		
	var arrow = arrow_scene.instantiate()
	get_tree().current_scene.add_child(arrow)
	
	var start_pos = _shoot_point.global_position if _shoot_point else global_position
	arrow.global_position = start_pos
	
	if _player != null and arrow.has_method("fire"):
		# Adicione um Vector2(0, -10) ou algo similar ao global_position do player
		# se quiser mirar no "peito" ao invés do "pé" do player.
		var target_pos = _player.global_position
		
		var calculated_velocity = _calculate_trajectory(start_pos, target_pos)
		arrow.fire(calculated_velocity)

func _calculate_trajectory(start: Vector2, target: Vector2) -> Vector2:
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	var displacement = target - start
	
	# Tempo estimado de voo baseado na distância horizontal e velocidade fixa.
	# Garante que não dividiremos por zero caso o player esteja na mesma posição X
	var time_of_flight = abs(displacement.x) / ARROW_SPEED_X
	if time_of_flight <= 0.01:
		time_of_flight = 0.01
		
	# Direção X (esq/dir) com velocidade constante
	var velocity_x = ARROW_SPEED_X * sign(displacement.x)
	
	# Cálculo do Y necessário para atingir o alvo no tempo exato.
	# Fórmula: Vy = (Δy - 0.5 * g * t²) / t
	var velocity_y = (displacement.y - 0.5 * gravity * time_of_flight * time_of_flight) / time_of_flight
	
	return Vector2(velocity_x, velocity_y)
