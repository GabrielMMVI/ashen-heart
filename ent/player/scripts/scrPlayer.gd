extends CharacterBody2D
@onready var ansprPlayer: AnimatedSprite2D = $ansprPlayer

const SPEED = 100.0
const JUMP_VELOCITY = -300.0

#Função de ataque
var is_attacking := false
func _attack_melee() -> void:
	if Input.is_action_just_pressed("attack") and not is_attacking:
		is_attacking = true
		ansprPlayer.play("attack_melee")
		await ansprPlayer.animation_finished
		is_attacking = false

func _physics_process(delta: float) -> void:
	#Checa se o personagem está atacando:
	_attack_melee()
	
	#Gravidade.
	if not is_on_floor():
		velocity += get_gravity() * delta
	#Mecânica de pulo:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	#Recebe os comandos do jogador:
	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if not is_attacking:
		if is_on_floor():
		#Animação de andar - Inverte a imagem se andar para a Direita:
			if direction > 0:
				ansprPlayer.flip_h = false
				ansprPlayer.play("walk")
			elif direction < 0:
				ansprPlayer.flip_h = true
				ansprPlayer.play("walk")
			else:
				#Animação Idle:
				ansprPlayer.play("idle")
		else:
			#Animação Pulo:
			ansprPlayer.play("jump")
	move_and_slide()
