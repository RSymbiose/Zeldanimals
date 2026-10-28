extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	# On vérifie si le corps est bien le gorille (par son nom ou un groupe)
	# Adapte "Gorilla" selon le nom exact de ton nœud gorille dans l'arborescence
	if body.name.contains("Gorilla") or body.is_in_group("gorilla"):
		var spawner = get_tree().get_first_node_in_group("player_spawner")
		if spawner and spawner.has_method("force_respawn"):
			spawner.force_respawn()
