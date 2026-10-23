extends Node3D
# stone_bridge.gd : pont de pierre avec un gros trou au milieu, construit au lancement.
# Le pont s'étend vers -Z depuis ce nœud. Le DESSUS du pont est à y = 0.
# Les collisions sont créées par le script (simples boîtes) : les assets ne servent
# qu'à l'apparence, donc pas de surprise de collision avec le décor importé.
#
#   départ (z=0) [ moitié 1 ]  ~~~ trou ~~~  [ moitié 2 ]  arrivée

@export_group("Dimensions")
@export var gap := 8.0                       # largeur du trou (m)
@export var tiles_per_half := 2              # nb de dalles en longueur, de chaque côté du trou
@export var tiles_wide := 1                  # nb de dalles en largeur
@export var tile_size := Vector2(4, 4)       # taille d'UNE dalle : X = largeur, Y = longueur (m)
@export var deck_thickness := 0.5            # épaisseur de la collision du sol

@export_group("Assets (à glisser depuis le dock Système de fichiers)")
@export var deck_tile: PackedScene           # dalle de sol (ex. KayKit : floor_tile_large)
@export var tile_offset := Vector3.ZERO      # corrige le pivot de la dalle si elle est décalée
@export var parapet: PackedScene             # petit mur / rambarde sur les côtés (facultatif)
@export var parapet_length := 2.0            # longueur d'une pièce de rambarde (m)
@export var parapet_inset := 0.25            # retrait par rapport au bord (m)
@export var parapet_yaw := 0.0               # rotation en degrés si la rambarde est de travers (essaie 90)
@export var rubble: Array[PackedScene] = []  # rochers / gravats posés au bord du trou
@export var rubble_per_edge := 4

@export_group("Aspect cassé")
@export var edge_tilt := 0.12                # inclinaison max (rad) des dalles du bord cassé
@export var side_barriers := true            # murs de collision invisibles sur les côtés


func _ready() -> void:
	var half_length := tiles_per_half * tile_size.y
	_build_half(0.0, half_length, false)                    # côté départ : bord cassé au bout
	_build_half(-(half_length + gap), half_length, true)    # côté arrivée : bord cassé au début


# Position (monde) du bord du trou côté arrivée : utile pour poser une cible de toile
func far_edge_global() -> Vector3:
	return to_global(Vector3(0, 0, -(tiles_per_half * tile_size.y + gap)))


func _build_half(z_start: float, length: float, edge_at_start: bool) -> void:
	var width := tiles_wide * tile_size.x
	var body := StaticBody3D.new()
	add_child(body)

	# --- Collision du sol ---
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, deck_thickness, length)
	cs.shape = box
	cs.position = Vector3(0, -deck_thickness / 2.0, z_start - length / 2.0)
	body.add_child(cs)

	# --- Barrières invisibles sur les côtés (évite de tomber sur le côté) ---
	if side_barriers:
		for side in [-1.0, 1.0]:
			var wall := CollisionShape3D.new()
			var wbox := BoxShape3D.new()
			wbox.size = Vector3(0.3, 1.2, length)
			wall.shape = wbox
			wall.position = Vector3(side * (width / 2.0 - 0.15), 0.6, z_start - length / 2.0)
			body.add_child(wall)

	# --- Dalles de sol ---
	if deck_tile:
		var edge_index := 0 if edge_at_start else tiles_per_half - 1
		var tilt_sign := 1.0 if edge_at_start else -1.0   # fait pencher vers le trou
		for iz in tiles_per_half:
			for ix in tiles_wide:
				var tile := deck_tile.instantiate() as Node3D
				body.add_child(tile)
				var x := (ix - (tiles_wide - 1) / 2.0) * tile_size.x
				var z := z_start - (iz + 0.5) * tile_size.y
				tile.position = Vector3(x, 0, z) + tile_offset
				if iz == edge_index:   # bord cassé : dalles de travers
					tile.rotation.y = randf_range(-0.08, 0.08)
					tile.rotation.x = tilt_sign * randf_range(0.0, edge_tilt)

	# --- Rambardes ---
	if parapet:
		var count := ceili(length / parapet_length)
		for side in [-1.0, 1.0]:
			for i in count:
				var p := parapet.instantiate() as Node3D
				body.add_child(p)
				p.position = Vector3(
					side * (width / 2.0 - parapet_inset), 0,
					z_start - (i + 0.5) * parapet_length)
				p.rotation_degrees.y = parapet_yaw

	# --- Gravats au bord du trou ---
	if not rubble.is_empty():
		var edge_z := z_start if edge_at_start else z_start - length
		var inward := -1.0 if edge_at_start else 1.0   # direction vers l'intérieur du pont
		for i in rubble_per_edge:
			var r := (rubble.pick_random() as PackedScene).instantiate() as Node3D
			body.add_child(r)
			r.position = Vector3(
				randf_range(-width / 2.0 + 0.5, width / 2.0 - 0.5), 0,
				edge_z + inward * randf_range(0.2, 1.5))
			r.rotation.y = randf_range(0.0, TAU)
			r.scale = Vector3.ONE * randf_range(0.6, 1.1)
