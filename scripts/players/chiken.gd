class_name ChickenPlayer
extends CharacterBody3D

@export var speed: float = 3.5
@export var jump_velocity: float = 4.0
@export var glide_fall_speed: float = -1.0
@export var mouse_sensitivity: float = 0.002

@export var chicken_mechanics: ChickenMechanics
@onready var head_pivot: Node3D = $HeadPivot
@onready var fallback_cam: Camera3D = $HeadPivot/FallbackCamera3D
@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var xr_camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var left_controller: XRController3D = $XROrigin3D/LeftController
@onready var right_controller: XRController3D = get_node_or_null("XROrigin3D/RightController") as XRController3D
@onready var chicken_audio: ChickenAudio = $AudioManager

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_xr_active: bool = false
var is_gliding: bool = false
var xr_jump_requested: bool = false

func _ready() -> void:
	# Résolution automatique de secours si non glissé dans l'inspecteur
	if chicken_mechanics == null:
		chicken_mechanics = find_child("ChickenMechanics", true, false) as ChickenMechanics

	if chicken_mechanics and chicken_audio:
		chicken_mechanics.egg_laid.connect(chicken_audio.play_lay_egg_sound)
	
	var xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		get_viewport().use_xr = true
		is_xr_active = true
		fallback_cam.current = false
		xr_camera.current = true

		# Sécurisation des trackers
		if left_controller:
			left_controller.tracker = &"left_hand"
			left_controller.button_pressed.connect(_on_xr_button_pressed)
		if right_controller:
			right_controller.tracker = &"right_hand"
			right_controller.button_pressed.connect(_on_xr_button_pressed)
	else:
		get_viewport().use_xr = false
		is_xr_active = false
		xr_camera.current = false
		fallback_cam.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if is_xr_active:
		return

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		head_pivot.rotation.x = clamp(head_pivot.rotation.x, deg_to_rad(-70), deg_to_rad(70))

func _physics_process(delta: float) -> void:
	var move_intent := Vector3.ZERO

	if not is_xr_active:
		# --- MODE PC ---
		if Input.is_action_just_pressed("lay_egg") and chicken_mechanics:
			chicken_mechanics.lay_egg()

		if is_on_floor() and Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity

		is_gliding = Input.is_action_pressed("jump") and not is_on_floor() and velocity.y < 0.0

		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		move_intent = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	else:
		# --- MODE VR ---
		if is_on_floor() and xr_jump_requested:
			velocity.y = jump_velocity
			xr_jump_requested = false

		is_gliding = not is_on_floor() and velocity.y < 0.0

		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var cam_transform = xr_camera.global_transform
		var forward = Vector3(-cam_transform.basis.z.x, 0.0, -cam_transform.basis.z.z).normalized()
		var right = Vector3(cam_transform.basis.x.x, 0.0, cam_transform.basis.x.z).normalized()

		move_intent = (forward * -input_dir.y + right * input_dir.x).normalized()
		if move_intent:
			rotation.y = atan2(-forward.x, -forward.z)

	# Vélocité horizontale
	if move_intent:
		velocity.x = move_intent.x * speed
		velocity.z = move_intent.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	# Gravité et planage
	if not is_on_floor():
		if is_gliding:
			velocity.y = max(velocity.y - (gravity * 0.15 * delta), glide_fall_speed)
		else:
			velocity.y -= gravity * delta

	move_and_slide()

	# Mise à jour du son aérien
	if chicken_audio:
		chicken_audio.update_airborne_sound(not is_on_floor())

func _on_xr_button_pressed(button_name: String) -> void:
	match button_name:
		"trigger_click":
			if chicken_mechanics:
				chicken_mechanics.lay_egg()
		"ax_button", "by_button":
			# Bouton de saut sur les contrôleurs Quest (A ou X)
			if is_on_floor():
				xr_jump_requested = true
