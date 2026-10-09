class_name SceneSpider

extends CharacterBody3D

@export var speed := 4.0
@export var climb_speed := 3.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.002
@export var web_range := 20.0
@export var web_pull_speed := 14.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var wall_ray: RayCast3D = $Head/Camera3D/WallRay
@onready var web_ray: RayCast3D = $Head/Camera3D/WebRay


var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_climbing := false
var web_point: Vector3
var web_active := false
var crosshair: ColorRect
var web_line: MeshInstance3D
var aim_marker: MeshInstance3D

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
		_toggle_web()


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	_update_climb_state()

	if is_climbing:
		_climb_movement(input_dir)
	else:
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
func _update_climb_state() -> void:
	var wants_climb: bool = Input.is_action_pressed("move_forward")
	var on_climbable: bool = wall_ray.is_colliding() \
		and wall_ray.get_collider().is_in_group("climbable")
	is_climbing = wants_climb and on_climbable


func _climb_movement(input_dir: Vector2) -> void:
	var n := wall_ray.get_collision_normal()          # normale du mur (vers nous)
	var wall_right := Vector3.UP.cross(n).normalized()
	var wall_up := n.cross(wall_right).normalized()

	# avant/arrière = monter/descendre ; gauche/droite = latéral
	var move := wall_up * -input_dir.y + wall_right * input_dir.x
	velocity = move * climb_speed - n * 1.0           # petite force pour rester collé


# ---------- Toile (grappin) ----------
func _toggle_web() -> void:
	if web_active:
		web_active = false
		return
	if web_ray.is_colliding():
		web_point = web_ray.get_collision_point()
		web_active = true


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

	var basis := Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, PI / 2.0)
	web_line.global_transform = Transform3D(basis, (start + end) / 2.0)