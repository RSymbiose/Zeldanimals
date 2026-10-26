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
@onready var chicken_audio: ChickenAudio = $AudioManager


var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_xr_active: bool = false
var is_gliding: bool = false

func _ready() -> void:
	var xr_interface = XRServer.find_interface("OpenXR")
	
	# Liaison du signal de ponte au lecteur audio
	if chicken_mechanics and chicken_audio:
		chicken_mechanics.egg_laid.connect(chicken_audio.play_lay_egg_sound)
		
	if xr_interface and xr_interface.is_initialized():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		get_viewport().use_xr = true
		is_xr_active = true
		fallback_cam.current = false
		xr_camera.current = true
		left_controller.button_pressed.connect(_on_xr_button_pressed)
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
		# Rotation horizontale (lacet) appliquée au corps complet
		rotate_y(-event.relative.x * mouse_sensitivity)
		# Rotation verticale (tangage) appliquée uniquement au pivot de la caméra
		head_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		head_pivot.rotation.x = clamp(head_pivot.rotation.x, deg_to_rad(-70), deg_to_rad(70))

func _physics_process(delta: float) -> void:
	# 1. GESTION DES COMMANDES CLAVIER (Exécuté uniquement sur PC)
	if not is_xr_active:
		if Input.is_action_just_pressed("lay_egg"):
			chicken_mechanics.lay_egg()

		is_gliding = Input.is_action_pressed("jump") and not is_on_floor() and velocity.y < 0.0

		if is_on_floor() and Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity

		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)
	else:
		# Emplacement pour la lecture du joystick VR si nécessaire
		pass

	# 2. PHYSIQUE UNIVERSELLE (Gravité et planage communs PC / VR)
	if not is_on_floor():
		if is_gliding:
			velocity.y = max(velocity.y - (gravity * 0.15 * delta), glide_fall_speed)
		else:
			velocity.y -= gravity * delta

	# 3. APPLICATION DU VECTEUR DE VÉLOCITÉ
	move_and_slide()

	# Active le son en boucle tant que la poule est en l'air (ou en planage)
	chicken_audio.update_airborne_sound(not is_on_floor())

func _on_xr_button_pressed(button_name: String) -> void:
	if button_name == "trigger_click":
		chicken_mechanics.lay_egg()
