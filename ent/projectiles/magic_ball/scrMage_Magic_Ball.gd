extends Area2D

# ==============================================================================
# CONSTANTES
# ==============================================================================
const SPEED            := 60.0
const KNOCKBACK_FORCE  := Vector2(50.0, 10.0)

# ── Sistema de crescimento ─────────────────────────────────────────────────────
#
#   O projétil nasce no tamanho e dano base (100%) e cresce progressivamente
#   conforme percorre distância, atingindo 200% ao completar MAX_GROWTH_DIST.
#
#   Dano:  DAMAGE_BASE (100%) ──────────────► DAMAGE_BASE × 4 (400%)
#   Escala:     SCALE_MIN     ──────────────►      SCALE_MAX
#               |─────────── MAX_GROWTH_DIST ────────────|
#
const DAMAGE_BASE       := 15.0   # Dano a 100% (recém lançado)
const DAMAGE_MAX_MULT   := 10.0    # Multiplicador máximo
const MAX_GROWTH_DIST   := 600.0  # Distância percorrida para atingir o máximo
const SCALE_MIN         := 0.7    # Escala inicial do projétil
const SCALE_MAX         := 10.0    # Escala ao atingir crescimento máximo

# ── Sistema de perseguição suave ──────────────────────────────────────────────
#
#   O projétil corrige sua direção para o player a cada frame, mas é limitado
#   a TURN_SPEED_DEG graus por segundo — sem curvas bruscas.
#   MAX_ANGLE_DEG impede que suba/desça mais de 45° do eixo de lançamento,
#   então ele nunca faz um looping, apenas suaves correções de trajetória.
#
#   Diagrama (lançado para a direita):
#
#              45° ──► limite superior
#         ─────────────────────────────► direção base (0°)
#             -45° ──► limite inferior
#
const TURN_SPEED_DEG    := 35.0   # Graus por segundo máximo de rotação
const MAX_ANGLE_DEG     := 45.0   # Desvio máximo acima/abaixo do eixo horizontal

# ==============================================================================
# VARIÁVEIS
# ==============================================================================
var velocity:           Vector2 = Vector2.ZERO
var _distance_traveled: float   = 0.0
var _growth_ratio:      float   = 0.0   # 0.0 = nasceu | 1.0 = máximo
var _player:            Node2D  = null  # Referência ao alvo
var _launch_angle:      float   = 0.0  # Ângulo de lançamento (base para o clamp)

# ==============================================================================
# PRONTO
# ==============================================================================
func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	scale = Vector2(SCALE_MIN, SCALE_MIN)

	get_tree().create_timer(15.0).timeout.connect(queue_free)

# ==============================================================================
# FUNÇÃO CHAMADA PELO MAGO
# ==============================================================================
func fire(direction: Vector2) -> void:
	velocity = direction * SPEED
	rotation = velocity.angle()

	# Salva o ângulo de lançamento como referência para o clamp de 45°
	_launch_angle = velocity.angle()

	# Guarda referência ao player para a perseguição
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]

	print("ENEMYFIRE")

# ==============================================================================
# FÍSICA, MOVIMENTO E CRESCIMENTO
# ==============================================================================
func _physics_process(delta: float) -> void:
	# ── Perseguição suave ────────────────────────────────────────────────────
	if is_instance_valid(_player):
		var current_angle := velocity.angle()
		var desired_angle := global_position.angle_to_point(_player.global_position)

		# Diferença de ângulo normalizada em (-PI, PI)
		var angle_diff := wrapf(desired_angle - current_angle, -PI, PI)

		# Rotação máxima permitida neste frame
		var max_turn := deg_to_rad(TURN_SPEED_DEG) * delta
		var turn     := clampf(angle_diff, -max_turn, max_turn)

		var new_angle := current_angle + turn

		# Clamp absoluto: nunca ultrapassa ±45° do ângulo de lançamento
		var abs_limit       := deg_to_rad(MAX_ANGLE_DEG)
		var diff_from_base  := wrapf(new_angle - _launch_angle, -PI, PI)
		new_angle = _launch_angle + clampf(diff_from_base, -abs_limit, abs_limit)

		velocity = Vector2(cos(new_angle), sin(new_angle)) * SPEED
		rotation = new_angle

	# ── Crescimento ──────────────────────────────────────────────────────────
	var movement := velocity * delta
	_distance_traveled += movement.length()
	_growth_ratio = clampf(_distance_traveled / MAX_GROWTH_DIST, 0.0, 1.0)

	var current_scale := lerpf(SCALE_MIN, SCALE_MAX, _growth_ratio)
	scale = Vector2(current_scale, current_scale)

	global_position += movement

# ==============================================================================
# DANO ATUAL — calculado a partir do ratio de crescimento
# ==============================================================================
func _current_damage() -> int:
	return roundi(lerpf(DAMAGE_BASE, DAMAGE_BASE * DAMAGE_MAX_MULT, _growth_ratio))

# ==============================================================================
# COLISÃO COM CENÁRIO (chão, paredes, TileMap)
# ==============================================================================
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		return
	queue_free()

# ==============================================================================
# COLISÃO COM O PLAYER
# ==============================================================================
func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hurtbox"):
		var player = area.get_parent()
		if player.has_method("take_damage"):
			var knockback_dir := global_position.direction_to(player.global_position)
			var dir_x := signf(knockback_dir.x)
			if dir_x == 0: dir_x = 1

			var applied_force := Vector2(KNOCKBACK_FORCE.x * dir_x, KNOCKBACK_FORCE.y)
			player.take_damage(_current_damage(), applied_force)
		queue_free()
