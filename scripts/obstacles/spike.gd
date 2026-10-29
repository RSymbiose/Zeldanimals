extends Area3D
# Pointes mortelles : tuent le gorille (PC ou VR), mais pas la poule ni l'araignée.

@export var debug := false   # affiche dans la console chaque corps qui touche la pointe


func _ready() -> void:
	# Le PlayerBody de XR Tools n'est pas sur la couche 1 (celle du gorille PC) : avec le
	# masque par défaut, l'Area3D ne le voit pas. On détecte donc toutes les couches
	# et on filtre ensuite dans _is_gorilla().
	collision_mask = 0xFFFFFFFF
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if debug:
		print("Pointe touchée par : ", body.name, " (", body.get_class(), ") couche = ", body.get("collision_layer"))
	if not _is_gorilla(body):
		return
	var spawner := get_tree().get_first_node_in_group("player_spawner")
	if spawner and spawner.has_method("force_respawn"):
		spawner.force_respawn()


func _is_gorilla(body: Node) -> bool:
	# Seul un corps de personnage compte (pas les éclats, les mains, le décor...)
	if not (body is CharacterBody3D):
		return false

	# PC : le corps du gorille
	if body.name.contains("Gorilla") or body.is_in_group("gorilla"):
		return true

	# VR : le PlayerBody de XR Tools est enfant du rig PlayerXR, qui connaît la forme active
	var rig: Node = body.get_parent()
	while rig != null and not (rig is PlayerXR):
		rig = rig.get_parent()
	return rig != null and (rig as PlayerXR).current_form == "gorilla"
