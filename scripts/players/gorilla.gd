extends CharacterBody3D

@export var speed := 5.0
@export var jump_velocity := 20.0       # le gorille saute haut
@export var mouse_sensitivity := 0.002
@export var smash_range := 2.5
@export var smash_force := 15.0

@onready var camera: Camera3D = $Head/Camera3D
@onready var smash_ray: RayCast3D = $Head/Camera3D/SmashRay

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	smash_ray.target_position = Vector3(0, 0, -smash_range)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	if event.is_action_pressed("smash"):
		smash()

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

func smash() -> void:
	smash_ray.force_raycast_update()
	if not smash_ray.is_colliding():
		return
	var target := smash_ray.get_collider()
	if target and target.has_method("on_smashed"):
		target.on_smashed(global_position.direction_to(smash_ray.get_collision_point()) * smash_force)
