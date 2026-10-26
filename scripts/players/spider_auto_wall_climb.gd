@tool
class_name SpiderAutoWallClimb
extends XRToolsMovementProvider

@export var climb_speed := 3.0
@export var wall_distance := 0.9
@export var input_action := "primary"
@export var forward_deadzone := 0.2
@export var order: int = 12

var _controller: XRController3D
var _camera: XRCamera3D
var _wall_ray: RayCast3D


func _enter_tree() -> void:
	_controller = XRHelpers.get_left_controller(self)


func _exit_tree() -> void:
	_controller = null


func _ready() -> void:
	super()
	_camera = XRHelpers.get_xr_camera(self)
	_wall_ray = RayCast3D.new()
	_wall_ray.name = "SpiderWallRay"
	_wall_ray.collision_mask = 1
	_wall_ray.target_position = Vector3(0.0, 0.0, -wall_distance)
	_wall_ray.enabled = true
	add_child(_wall_ray)


func physics_movement(_delta: float, player_body: XRToolsPlayerBody, disabled: bool):
	if disabled or not enabled or not _controller or not _controller.get_is_active():
		is_active = false
		return

	var input: Vector2 = XRToolsUserSettings.get_adjusted_vector2(_controller, input_action)
	if input.y < forward_deadzone:
		is_active = false
		return

	# Keep wall detection horizontal so the climbing camera offset cannot make
	# the ray point at the sky and cancel the climb.
	var ray_origin := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		is_active = false
		return
	forward = forward.normalized()
	_wall_ray.global_position = ray_origin
	_wall_ray.look_at(ray_origin + forward, Vector3.UP)
	_wall_ray.force_raycast_update()
	if not _wall_ray.is_colliding():
		is_active = false
		return

	var wall_normal := _wall_ray.get_collision_normal()
	if absf(wall_normal.y) > 0.6:
		is_active = false
		return

	is_active = true
	player_body.velocity = Vector3.ZERO
	player_body.move_player(Vector3.UP * climb_speed)
	return true


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if not XRHelpers.get_xr_controller(self):
		warnings.append("This node must be within a branch of an XRController3D node")
	return warnings
