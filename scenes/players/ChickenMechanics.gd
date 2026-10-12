# ChickenMechanics.gd
class_name ChickenMechanics
extends Node3D

@export var egg_scene: PackedScene
@export var egg_cooldown: float = 0.5
@export var spawn_offset: Vector3 = Vector3(0, -0.3, -0.2) # En arrière et en dessous

var can_lay: bool = true

func lay_egg(player_global_transform: Transform3D) -> void:
	if not can_lay or egg_scene == null:
		return

	can_lay = false
	var egg: RigidBody3D = egg_scene.instantiate()
	get_tree().root.add_child(egg)
	
	# Positionnement derrière le joueur
	var spawn_pos = player_global_transform.origin + (player_global_transform.basis * spawn_offset)
	egg.global_position = spawn_pos
	
	# Éjection légère vers l'arrière
	var backward_dir = -player_global_transform.basis.z
	egg.apply_central_impulse(backward_dir * 1.5)

	# Gestion du délai
	await get_tree().create_timer(egg_cooldown).timeout
	can_lay = true
