extends Area2D

@export var weapon_id: int = 1 

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# TESTE 1: Se qualquer coisa encostar no arco, isso vai aparecer na tela
	print("ALGO ENCOSTOU NO ARCO: ", body.name) 
	
	if body.is_in_group("player"):
		# TESTE 2: Se o Godot reconhecer o grupo do player
		print("O grupo 'player' foi detectado!") 
		
		if body.has_method("pickup_weapon"):
			body.pickup_weapon(weapon_id)
			queue_free()
		else:
			print("ERRO: O Player não tem a função pickup_weapon!")
