extends StaticBody3D

@export var health := 1
@export var pieces := Vector3i(4, 4, 2)      # découpe en X, Y, Z
@export var explosion_strength := 4.0
@export var shard_mass := 0.5
@export var shard_lifetime := 3.0            # secondes avant disparition

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision: CollisionShape3D = $CollisionShape3D

func on_smashed(impulse: Vector3) -> void:
	health -= 1
	if health > 0:
		return
	_shatter(impulse)

func _shatter(impulse: Vector3) -> void:
	var size: Vector3 = (collision.shape as BoxShape3D).size
	var piece_size := Vector3(size.x / pieces.x, size.y / pieces.y, size.z / pieces.z)
	var material := mesh_instance.get_active_material(0)
	var origin_xform := collision.global_transform
	var parent := get_parent()

	for x in pieces.x:
		for y in pieces.y:
			for z in pieces.z:
				var local_pos := Vector3(
					(x + 0.5) * piece_size.x - size.x / 2.0,
					(y + 0.5) * piece_size.y - size.y / 2.0,
					(z + 0.5) * piece_size.z - size.z / 2.0)
				_spawn_shard(parent, origin_xform, local_pos, piece_size, material, impulse)

	queue_free()

func _spawn_shard(parent: Node, origin_xform: Transform3D, local_pos: Vector3,
		piece_size: Vector3, material: Material, impulse: Vector3) -> void:
	var shard := RigidBody3D.new()
	shard.mass = shard_mass
	shard.collision_layer = 4          # couche 3 : le joueur ne les "voit" pas
	shard.collision_mask = 1 | 4       # collisionne avec le décor et les autres éclats

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = piece_size * 0.95
	shape.shape = box

	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = piece_size * 0.95
	box_mesh.material = material
	mesh.mesh = box_mesh

	shard.add_child(shape)
	shard.add_child(mesh)
	parent.add_child(shard)
	shard.global_transform = Transform3D(origin_xform.basis, origin_xform * local_pos)

	# Poussée : direction du coup + éclatement depuis le centre + hasard
	var outward := (origin_xform.basis * local_pos).normalized()
	var push := impulse.normalized() * explosion_strength \
		+ outward * 1.5 \
		+ Vector3(randf_range(-1, 1), randf_range(0, 2), randf_range(-1, 1))
	shard.apply_central_impulse(push)
	shard.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))

	# Disparition : l'éclat rétrécit puis est supprimé
	var tween := shard.create_tween()
	tween.tween_interval(shard_lifetime + randf_range(0.0, 1.0))
	tween.tween_property(mesh, "scale", Vector3.ZERO, 0.5)
	tween.tween_callback(shard.queue_free)
