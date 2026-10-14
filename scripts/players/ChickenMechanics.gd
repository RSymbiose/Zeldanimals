# ChickenMechanics.gd
class_name ChickenMechanics
extends Marker3D

signal egg_laid # Déclaration du signal de ponte

@export var egg_scene: PackedScene
@export var lay_cooldown: float = 0.6
@export var ejection_force: float = 0.03 # Force d'expulsion vers l'arrière

var can_lay: bool = true

func lay_egg(player_transform: Transform3D = Transform3D()) -> void:
	if not can_lay or egg_scene == null:
		return
		
	can_lay = false

	var egg: RigidBody3D = egg_scene.instantiate()
	
	# Désactive la collision immédiate avec le parent (la poule)
	var parent_body = get_parent() as CollisionObject3D
	if parent_body:
		egg.add_collision_exception_with(parent_body)

	# Instanciation au niveau du monde pour découpler l'œuf des mouvements futurs de la poule
	get_tree().root.add_child(egg)
	egg.global_position = global_position

	# Extraction directe de l'axe arrière (+Z) dans le repère global du Marker3D
	var backward_dir: Vector3 = global_transform.basis.z.normalized()
	
	# Éjection : impulsion arrière légèrement orientée vers le bas
	var impulse_vector = (backward_dir * 0.8 + Vector3.DOWN * 0.2).normalized() * ejection_force
	egg.apply_central_impulse(impulse_vector)

	# Déclenchement de l'événement sonore
	egg_laid.emit()
	
	# Réactivation après le cooldown
	await get_tree().create_timer(lay_cooldown).timeout
	can_lay = true
