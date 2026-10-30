@tool
class_name SpiderAutoWallClimb
extends XRToolsMovementProvider

@export var climb_speed := 3.0
@export var wall_distance := 0.9
@export var input_action := "primary"
@export var forward_deadzone := 0.2
@export var order: int = 12

@export_group("Rebord")
@export var ledge_probe_drop := 0.3   # distance (m) sous la caméra du rayon bas
@export var rise_time := 0.35         # on continue de monter pour dépasser le rebord (s)
@export var push_time := 0.35         # puis on avance au-dessus du rebord (s)
@export var push_speed := 2.5         # vitesse d'avance au-dessus du rebord

enum Phase { NONE, CLIMB, RISE, PUSH }

var _controller: XRController3D
var _camera: XRCamera3D
var _wall_ray: RayCast3D
var _low_ray: RayCast3D

var _phase := Phase.NONE
var _phase_time := 0.0
var _ledge_forward := Vector3.ZERO


func _enter_tree() -> void:
	_controller = XRHelpers.get_left_controller(self)


func _exit_tree() -> void:
	_controller = null


func _ready() -> void:
	super()
	_camera = XRHelpers.get_xr_camera(self)
	_wall_ray = _make_ray("SpiderWallRay")
	_low_ray = _make_ray("SpiderLowRay")


func _make_ray(ray_name: String) -> RayCast3D:
	var ray := RayCast3D.new()
	ray.name = ray_name
	ray.collision_mask = 1
	ray.target_position = Vector3(0.0, 0.0, -wall_distance)
	ray.enabled = true
	add_child(ray)
	return ray


func physics_movement(delta: float, player_body: XRToolsPlayerBody, disabled: bool):
	if disabled or not enabled or not _controller or not _controller.get_is_active():
		_reset()
		return

	# Franchissement du rebord : prioritaire tant qu'il dure
	if _phase == Phase.RISE or _phase == Phase.PUSH:
		_run_ledge(delta, player_body)
		return true

	var input: Vector2 = XRToolsUserSettings.get_adjusted_vector2(_controller, input_action)
	if input.y < forward_deadzone:
		_reset()
		return

	# Détection horizontale : l'inclinaison de la caméra pendant l'escalade
	# ne doit pas faire pointer le rayon vers le ciel.
	var forward := -_camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		_reset()
		return
	forward = forward.normalized()

	var origin := _camera.global_position
	var high_hit := _cast(_wall_ray, origin, forward)
	var low_hit := _cast(_low_ray, origin + Vector3.DOWN * ledge_probe_drop, forward)

	if not high_hit:
		# Le mur continue plus bas mais plus à hauteur de tête : c'est un rebord
		if _phase == Phase.CLIMB and low_hit:
			_ledge_forward = forward
			_phase = Phase.RISE
			_phase_time = 0.0
			_run_ledge(delta, player_body)
			return true
		_reset()
		return

	_phase = Phase.CLIMB
	is_active = true
	player_body.velocity = Vector3.ZERO
	player_body.move_player(Vector3.UP * climb_speed)
	return true


# Lance un rayon depuis une position, vers l'avant, et vérifie que la surface est verticale
func _cast(ray: RayCast3D, origin: Vector3, forward: Vector3) -> bool:
	ray.global_position = origin
	ray.look_at(origin + forward, Vector3.UP)
	ray.force_raycast_update()
	if not ray.is_colliding():
		return false
	return absf(ray.get_collision_normal().y) <= 0.6


func _run_ledge(delta: float, player_body: XRToolsPlayerBody) -> void:
	is_active = true
	_phase_time += delta
	player_body.velocity = Vector3.ZERO
	if _phase == Phase.RISE:
		player_body.move_player(Vector3.UP * climb_speed)
		if _phase_time >= rise_time:
			_phase = Phase.PUSH
			_phase_time = 0.0
	else:
		player_body.move_player(_ledge_forward * push_speed + Vector3.UP * 0.5)
		if _phase_time >= push_time:
			_reset()


func _reset() -> void:
	_phase = Phase.NONE
	_phase_time = 0.0
	is_active = false


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if not XRHelpers.get_xr_controller(self):
		warnings.append("This node must be within a branch of an XRController3D node")
	return warnings