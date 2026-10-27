# BreakableDoor.gd
class_name BreakableDoor
extends StaticBody3D

@export var health: int = 1
@export var particles: GPUParticles3D
@export var collision_shape: CollisionShape3D
@export var visual_mesh: Node3D # Glisse ici ton MeshInstance3D ou le nœud parent de tes maillages

var is_broken: bool = false

func _ready() -> void:
	# Résolution automatique des références si non renseignées dans l'inspecteur
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape3D")
	if visual_mesh == null:
		visual_mesh = get_node_or_null("MeshInstance3D")
	if particles == null:
		particles = get_node_or_null("GPUParticles3D")

	# Sécurisation des drapeaux d'émission
	if particles:
		particles.one_shot = true
		particles.emitting = false

func on_smashed(_impulse: Vector3 = Vector3.ZERO) -> void:
	if is_broken:
		return

	health -= 1
	if health <= 0:
		_break()

func _break() -> void:
	is_broken = true

	# 1. Libération immédiate du passage physique
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	# 2. Masquage propre du maillage intact
	if visual_mesh:
		visual_mesh.visible = false
	else:
		# Parcours exhaustif des descendants avec vérification dynamique d'héritage
		for child in find_children("*", "", true, false):
			if child is MeshInstance3D:
				child.visible = false

	# 3. Déclenchement de la salve de débris GPU
	var wait_duration: float = 1.0
	if particles:
		particles.restart()
		wait_duration = particles.lifetime

	# 4. Suppression mémoire calée sur l'extinction des débris
	await get_tree().create_timer(wait_duration).timeout
	queue_free()
