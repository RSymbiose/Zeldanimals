extends MeshInstance3D

@export var health := 1

@export_group("Éclats")
@export var shard_size := 0.1            # Taille d'un éclat (m)
@export var max_shards := 40             # Plafond pour le Quest (performance VR)
@export var keep_ratio := 0.7            # Part des cases qui deviennent un éclat (0..1)
@export var shard_mass := 0.3
@export var explosion_speed := 5.0       # Vitesse d'éjection
@export var lifetime := 1.0              # Temps avant que les éclats rétrécissent
@export var collide_between_shards := false  
@export var debris_colors: Array[Color] = [
	Color(0.55, 0.33, 0.2),    # Bois
	Color(0.4, 0.24, 0.14),    # Bois foncé
	Color(0.45, 0.5, 0.55),    # Métal / Clous
]

var _materials: Array[StandardMaterial3D] = []

# Fonction appelée par le gorille quand il tape la porte
func on_smashed(impulse: Vector3) -> void:
	health -= 1
	if health > 0:
		return
	_break(impulse)

func _break(impulse: Vector3) -> void:
	var parent: Node = get_parent()
	if parent == null:
		parent = get_tree().root
	var hit_dir := impulse.normalized()

	var meshes: Array[MeshInstance3D] = []
	
	# Comme le script est sur le MeshInstance3D racine, on l'ajoute directement !
	meshes.append(self)
	
	# On cherche aussi s'il y a d'autres meshs enfants au cas où
	for node in find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)

	_materials.clear()
	for c in debris_colors:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		_materials.append(m)

	# Ajuste la taille si trop d'éclats
	var size := shard_size
	while _count_cells(meshes, size) * keep_ratio > max_shards and size < 5.0:
		size *= 1.2

	for mesh in meshes:
		_shatter_mesh(parent, mesh, size, hit_dir)

	# Supprime toute la porte (visuel + StaticBody3D + collisions) d'un seul coup !
	queue_free()

func _grid(mesh: MeshInstance3D, size: float) -> Vector3i:
	var s := mesh.get_aabb().size * mesh.global_transform.basis.get_scale().abs()
	return Vector3i(
		maxi(1, ceili(s.x / size)),
		maxi(1, ceili(s.y / size)),
		maxi(1, ceili(s.z / size)))

func _count_cells(meshes: Array[MeshInstance3D], size: float) -> int:
	var total := 0
	for m in meshes:
		var g := _grid(m, size)
		total += g.x * g.y * g.z
	return total

func _shatter_mesh(parent: Node, mesh: MeshInstance3D, size: float, hit_dir: Vector3) -> void:
	var xform := mesh.global_transform
	var scale_xyz := xform.basis.get_scale().abs()
	var rot := xform.basis.orthonormalized()
	var aabb := mesh.get_aabb()
	var grid := _grid(mesh, size)
	var cell := Vector3(aabb.size.x / grid.x, aabb.size.y / grid.y, aabb.size.z / grid.z)

	for x in grid.x:
		for y in grid.y:
			for z in grid.z:
				if randf() > keep_ratio:
					continue
				var local_pos := aabb.position + Vector3(
					(x + 0.5) * cell.x, (y + 0.5) * cell.y, (z + 0.5) * cell.z)
				var world_pos := xform * local_pos
				_spawn_shard(parent, Transform3D(rot, world_pos), cell * scale_xyz, hit_dir)

func _spawn_shard(parent: Node, xform: Transform3D, cell_size: Vector3, hit_dir: Vector3) -> void:
	var shard_dim := (cell_size * randf_range(0.6, 1.0)).max(Vector3.ONE * 0.05)

	var shard := RigidBody3D.new()
	shard.mass = shard_mass
	shard.collision_layer = 4              
	shard.collision_mask = (1 | 4) if collide_between_shards else 1

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = shard_dim
	shape.shape = box

	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = shard_dim
	if not _materials.is_empty():
		box_mesh.material = _materials.pick_random()
	mesh.mesh = box_mesh

	shard.add_child(shape)
	shard.add_child(mesh)
	parent.add_child(shard)
	shard.global_transform = xform

	var outward := (xform.origin - global_position).normalized()
	shard.linear_velocity = hit_dir * explosion_speed \
		+ outward * explosion_speed * 0.5 \
		+ Vector3(randf_range(-1, 1), randf_range(1, 2), randf_range(-1, 1))
	shard.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))

	var tween := shard.create_tween()
	tween.tween_interval(lifetime + randf_range(0.0, 1.0))
	tween.tween_property(mesh, "scale", Vector3.ZERO, 0.5)
	tween.tween_callback(shard.queue_free)
