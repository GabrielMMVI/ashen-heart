extends StaticBody2D

@export var fade_speed: float = 3.0

# Ajustado para os nomes exatos da sua árvore de nós da cena secret_wall_3
@onready var wall_sprite = $Sprite2D
@onready var trigger_area = $Sprite2D/Area2D
@onready var collision = $CollisionShape2D

var target_alpha: float = 1.0

func _ready():
	trigger_area.body_entered.connect(_on_player_entered)
	trigger_area.body_exited.connect(_on_player_exited)

func _process(delta):
	# Suaviza a opacidade do Sprite principal da parede
	wall_sprite.modulate.a = move_toward(wall_sprite.modulate.a, target_alpha, fade_speed * delta)
	
	# Desativa a colisão física da parede se ela já sumiu quase toda (alpha menor que 0.1)
	collision.set_deferred("disabled", wall_sprite.modulate.a < 0.1)

func _on_player_entered(body):
	print("Entrou: ", body.name)
	if body.is_in_group("player") or body.name == "chbPlayer":
		print("É o player!")
		target_alpha = 0.0

func _on_player_exited(body):
	print("Saiu: ", body.name)
	if body.is_in_group("player") or body.name == "chbPlayer":
		target_alpha = 1.0
