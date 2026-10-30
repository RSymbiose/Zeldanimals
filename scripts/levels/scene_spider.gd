class_name SceneSpider

extends CharacterBody3D

@export var speed := 4.0
@export var climb_speed := 3.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.002
@export var web_range := 20.0
@export var web_pull_speed := 14.0

@export_group("Escalade")
@export var wall_distance := 0.9       # portée de détection du mur (m)
@export var ledge_probe_drop := 0.3    # le rayon bas est placé sous la tête de cette distance (m)
@export var rise_time := 0.35          # on continue de monter pour dépasser le rebord (s)
@export var push_time := 0.35          # puis on avance au-dessus du rebord (s)
@export var push_speed := 2.5          # vitesse d'avance au-dessus du rebord

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var wall_ray: RayCast3D = $Head/Camera3D/WallRay   # non utilisé : l'escalade interroge la physique directement
@onready var web_ray: RayCast3D = $Head/Camera3D/WebRay

enum Phase { NONE, CLIMB, RISE, PUSH }

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_climbing := false
var web_point: Vector3
var web_active := false
var crosshair: ColorRect
var web_line: MeshInstance3D
var aim_marker: MeshInstance3D

var _phase := Phase.NONE
var _phase_time := 0.0
var _ledge_forward := Vector3.ZERO


func _process(_delta: float) -> void:
	_update_visuals()


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	web_ray.target_position = Vector3(0, 0, -web_range)
	_create_crosshair()
	_create_web_visuals()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	if event.is_action_pressed("ability_primary"):
		_start_web()
	elif event.is_action_released("ability_primary"):
		_stop_web()


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	is_climbing = _climb_step(input_dir, delta)
	if not is_climbing:
		_ground_movement(input_dir, delta)

	if web_active:
		_apply_web(delta)

	move_and_slide()


# ---------- Mouvement normal ----------
func _ground_movement(input_dir: Vector2, delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if dir != Vector3.ZERO:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)


# ---------- Escalade ----------
# Renvoie true si l'escalade gère la vitesse à cette frame.
# Comme en VR : toute surface presque verticale est grimpable, sauf le groupe "not_climbable".
func _climb_step(input_dir: Vector2, delta: float) -> bool:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	# Franchissement du rebord : prioritaire tant qu'il dure
	if _phase == Phase.RISE or _phase == Phase.PUSH:
		_run_ledge(delta)
		return true

	if not Input.is_action_pressed("move_forward"):
		_phase = Phase.NONE
		return false

	var origin := head.global_position
	var high := _probe(origin, forward)
	var low := _probe(origin + Vector3.DOWN * ledge_probe_drop, forward)

	if high.is_empty():
		# Le mur continue plus bas mais plus à hauteur de tête : c'est un rebord
		if _phase == Phase.CLIMB and not low.is_empty():
			_phase = Phase.RISE
			_phase_time = 0.0
			_ledge_forward = forward
			_run_ledge(delta)
			return true
		_phase = Phase.NONE
		return false

	_phase = Phase.CLIMB
	_climb_movement(high["normal"], input_dir)
	return true


# Lance un rayon vers l'avant. Renvoie le résultat si la surface est grimpable, sinon {}.
func _probe(from: Vector3, forward: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, from + forward * wall_distance)
	query.exclude = [get_rid()]
	query.collision_mask = collision_mask
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	if absf(hit["normal"].y) > 0.6:         # sol ou plafond : on ne grimpe pas
		return {}
	var collider := hit["collider"] as Node
	if collider != null and collider.is_in_group("not_climbable"):
		return {}
	return hit


func _climb_movement(n: Vector3, input_dir: Vector2) -> void:
	var wall_right := Vector3.UP.cross(n).normalized()
	var wall_up := n.cross(wall_right).normalized()

	# avant/arrière = monter/descendre ; gauche/droite = latéral
	var move := wall_up * -input_dir.y + wall_right * input_dir.x
	velocity = move * climb_speed - n * 1.0           # petite force pour rester collé


func _run_ledge(delta: float) -> void:
	_phase_time += delta
	if _phase == Phase.RISE:
		velocity = Vector3.UP * climb_speed
		if _phase_time >= rise_time:
			_phase = Phase.PUSH
			_phase_time = 0.0
	else:
		velocity = _ledge_forward * push_speed + Vector3.UP * 0.5
		if _phase_time >= push_time:
			_phase = Phase.NONE


# ---------- Toile (grappin) ----------
func _start_web() -> void:
	if web_ray.is_colliding():
		web_point = web_ray.get_collision_point()
		web_active = true


func _stop_web() -> void:
	web_active = false


func _apply_web(delta: float) -> void:
	var to_point := web_point - global_position
	if to_point.length() < 1.5:
		web_active = false
		return
	velocity = velocity.lerp(to_point.normalized() * web_pull_speed, 5.0 * delta)


# ---------- Visuels ----------
func _create_crosshair() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	crosshair = ColorRect.new()
	crosshair.color = Color.WHITE
	crosshair.custom_minimum_size = Vector2(6, 6)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)


func _create_web_visuals() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.95, 0.95)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Fil de toile (cylindre très fin)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.02
	cyl.radial_segments = 6
	cyl.height = 1.0
	cyl.material = mat

	web_line = MeshInstance3D.new()
	web_line.mesh = cyl
	web_line.top_level = true      # ne suit pas le parent, on le place nous-mêmes
	web_line.visible = false
	web_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(web_line)

	# Repère à l'endroit visé
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	sphere.material = mat

	aim_marker = MeshInstance3D.new()
	aim_marker.mesh = sphere
	aim_marker.top_level = true
	aim_marker.visible = false
	aim_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(aim_marker)


func _update_visuals() -> void:
	var aiming := web_ray.is_colliding()

	# Curseur vert + repère quand on vise quelque chose à portée
	crosshair.color = Color.GREEN if aiming and not web_active else Color.WHITE
	aim_marker.visible = aiming and not web_active
	if aiming:
		aim_marker.global_position = web_ray.get_collision_point()

	# Fil de toile
	if web_active:
		var start := camera.global_position \
			+ camera.global_transform.basis * Vector3(0.25, -0.3, -0.3)
		_draw_web_line(start, web_point)
	else:
		web_line.visible = false


func _draw_web_line(start: Vector3, end: Vector3) -> void:
	var dir := end - start
	var distance := dir.length()
	if distance < 0.01:
		web_line.visible = false
		return

	web_line.visible = true
	(web_line.mesh as CylinderMesh).height = distance

	var up := Vector3.UP
	if absf(dir.normalized().y) > 0.99:
		up = Vector3.RIGHT          # évite le bug quand on tire pile en haut/bas

	var look_basis := Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, PI / 2.0)
	web_line.global_transform = Transform3D(look_basis, (start + end) / 2.0)