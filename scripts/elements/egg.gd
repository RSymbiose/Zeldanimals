# Egg.gd
extends RigidBody3D

@export var max_lifetime: float = 25.0 # Nettoyage mémoire automatique

func _ready() -> void:
	# Autodestruction après expiration du timer
	get_tree().create_timer(max_lifetime).timeout.connect(queue_free)
