extends Marker2D

# ==============================================================================
# CONFIGURAÇÕES DO SPAWNER (Ajustáveis no Inspector)
# ==============================================================================
@export var enemy_scene: PackedScene = preload("res://ent/enemies/Red_ranger/Red_Ranger.tscn")
@export var max_enemies_alive := 3 
@export var spawn_interval := 4.0   
@export var min_spawn_distance := 150.0 
@export var max_spawn_distance := 800.0 

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================
var _current_enemies_alive := 0
var _spawn_timer: Timer

# ==============================================================================
# PRONTO
# ==============================================================================
func _ready() -> void:
	# Esconde o Marker2D quando o jogo rodar (útil apenas no editor)
	visible = false 
	
	# Cria o timer dinamicamente via código para não poluir a árvore de nós
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = spawn_interval
	_spawn_timer.autostart = true
	_spawn_timer.timeout.connect(_on_timer_timeout)
	add_child(_spawn_timer)

# ==============================================================================
# LÓGICA DE GERAÇÃO
# ==============================================================================
func _on_timer_timeout() -> void:
	if not enemy_scene:
		push_warning("Spawner sem cena de inimigo definida: ", name)
		return
		
	if _current_enemies_alive >= max_enemies_alive:
		return # Limite atingido, não gera mais
		
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
		
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Verifica se o player está na "zona ideal" (nem muito perto, nem muito longe)
	if distance_to_player >= min_spawn_distance and distance_to_player <= max_spawn_distance:
		_spawn_enemy()

func _spawn_enemy() -> void:
	var enemy = enemy_scene.instantiate()
	
	# Adiciona o inimigo no nó pai do spawner (geralmente a raiz do Mapa)
	get_parent().add_child(enemy)
	enemy.global_position = global_position
	
	_current_enemies_alive += 1
	
	# "Escuta" quando o inimigo for destruído (queue_free) para liberar espaço
	enemy.tree_exited.connect(_on_enemy_died)

# ==============================================================================
# CONTROLE DE MEMÓRIA
# ==============================================================================
func _on_enemy_died() -> void:
	# Reduz a contagem quando o inimigo morre, permitindo que o Timer gere novos
	_current_enemies_alive -= 1
