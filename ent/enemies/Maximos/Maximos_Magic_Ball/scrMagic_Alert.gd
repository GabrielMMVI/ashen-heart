extends Node2D

# ==============================================================================
# NÓS REFERENCIADOS
# ==============================================================================
@onready var _sprite: AnimatedSprite2D = $ansprAlert

# ==============================================================================
# PRONTO
# ==============================================================================
func _ready() -> void:
	# Quando a animação terminar, some da cena automaticamente
	_sprite.animation_finished.connect(queue_free)
	_sprite.play("alert")
