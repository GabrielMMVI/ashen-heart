extends StaticBody2D

@export var fade_speed: float = 3.0

@onready var wall_sprite = $WallSprite
@onready var trigger_area = $TriggerArea
@onready var collision = $CollisionShape2D

var target_alpha: float = 1.0

func _ready():
	trigger_area.body_entered.connect(_on_player_entered)
	trigger_area.body_exited.connect(_on_player_exited)

func _process(delta):
	wall_sprite.modulate.a = move_toward(wall_sprite.modulate.a, target_alpha, fade_speed * delta)
	collision.set_deferred("disabled", wall_sprite.modulate.a < 0.1)

func _on_player_entered(body):
	print("Entrou: ", body.name)
	if body.is_in_group("player"):
		print("É o player!")
		target_alpha = 0.0

func _on_player_exited(body):
	print("Saiu: ", body.name)
	if body.is_in_group("player"):
		target_alpha = 1.0
