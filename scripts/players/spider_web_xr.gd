@tool
class_name SpiderWebXR
extends XRToolsMovementProvider

@export var web_range := 20.0
@export var pull_speed := 14.0
@export var pull_smoothing := 5.0
@export var web_button_action := "trigger_click"
@export var order: int = 20

var _controller: XRController3D
var _camera: XRCamera3D
var _web_ray: RayCast3D
var _web_point := Vector3.ZERO
var _button_was_pressed := false
var _web_visual_parent: Node3D
var _web_visual: CSGBox3D
var _web_target_visual: CSGSphere3D


func _enter_tree() -> void:
	_controller = XRHelpers.get_right_controller(self)


func _exit_tree() -> void:
	_controller = null


func _ready() -> void:
	super()
	_camera = XRHelpers.get_xr_camera(self)
	_web_ray = RayCast3D.new()
	_web_ray.name = "SpiderWebRay"
	_web_ray.collision_mask = 1
	_web_ray.target_position = Vector3(0.0, 0.0, -web_range)
	_web_ray.enabled = true
	add_child(_web_ray)
	_web_visual_parent = Node3D.new()
	_web_visual_parent.name = "SpiderWebVisualParent"
	get_tree().current_scene.add_child(_web_visual_parent)
	_web_visual = CSGBox3D.new()
	_web_visual.name = "SpiderWebVisual"
	_web_visual.size = Vector3(0.05, 0.05, 1.0)
	_web_visual.use_collision = false
	var web_material := StandardMaterial3D.new()
	web_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	web_material.emission_enabled = true
	web_material.emission = Color(0.8, 0.8, 0.8, 1.0)
	web_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_web_visual.material = web_material
	_web_visual.visible = false
	_web_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_web_visual_parent.add_child(_web_visual)
	_web_target_visual = CSGSphere3D.new()
	_web_target_visual.name = "SpiderWebTargetVisual"
	_web_target_visual.radius = 0.08
	_web_target_visual.radial_segments = 16
	_web_target_visual.rings = 8
	_web_target_visual.material = web_material
	_web_target_visual.visible = false
	_web_target_visual.top_level = true
	_web_target_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(_web_target_visual)
	_create_crosshair()


func _create_crosshair() -> void:
	var layer := CanvasLayer.new()
	layer.name = "SpiderWebCrosshair"
	add_child(layer)
	var horizontal := ColorRect.new()
	horizontal.color = Color.WHITE
	horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal.set_anchors_preset(Control.PRESET_CENTER)
	horizontal.offset_left = -8.0
	horizontal.offset_right = 8.0
	horizontal.offset_top = -1.0
	horizontal.offset_bottom = 1.0
	layer.add_child(horizontal)
	var vertical := ColorRect.new()
	vertical.color = Color.WHITE
	vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vertical.set_anchors_preset(Control.PRESET_CENTER)
	vertical.offset_left = -1.0
	vertical.offset_right = 1.0
	vertical.offset_top = -8.0
	vertical.offset_bottom = 8.0
	layer.add_child(vertical)


func _process(_delta: float) -> void:
	if is_active:
		_update_web_visual()


func physics_movement(delta: float, player_body: XRToolsPlayerBody, disabled: bool):
	if disabled or not enabled or not _controller or not _controller.get_is_active():
		_button_was_pressed = false
		is_active = false
		_web_visual.visible = false
		_web_target_visual.visible = false
		return

	var button_pressed := _controller.is_button_pressed(web_button_action)
	if button_pressed and not _button_was_pressed:
		_fire_web()
	_button_was_pressed = button_pressed

	if not button_pressed or not is_active:
		is_active = false
		_web_visual.visible = false
		_web_target_visual.visible = false
		return

	var to_point := _web_point - player_body.global_position
	if to_point.length() < 1.5:
		is_active = false
		_web_visual.visible = false
		_web_target_visual.visible = false
		return

	var pull_velocity := to_point.normalized() * pull_speed
	player_body.velocity = player_body.velocity.lerp(pull_velocity, pull_smoothing * delta)
	player_body.velocity = player_body.move_player(player_body.velocity)
	return true


func _fire_web() -> void:
	_web_ray.global_position = _camera.global_position
	var forward := -_camera.global_transform.basis.z
	_web_ray.look_at(_camera.global_position + forward, Vector3.UP)
	_web_ray.force_raycast_update()
	if not _web_ray.is_colliding():
		is_active = false
		_web_visual.visible = false
		_web_target_visual.visible = false
		return
	_web_point = _web_ray.get_collision_point()
	is_active = true
	_update_web_visual()


func _update_web_visual() -> void:
	var start := _camera.global_position
	var offset := _web_point - start
	var length := offset.length()
	if length <= 0.01:
		_web_visual.visible = false
		return
	_web_visual_parent.global_position = start
	_web_visual_parent.look_at(_web_point, Vector3.UP)
	_web_visual.position = Vector3(0.0, 0.0, -length * 0.5)
	_web_visual.scale = Vector3(1.0, 1.0, length)
	_web_target_visual.global_position = _web_point
	_web_target_visual.visible = true
	_web_visual.visible = true


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if not XRHelpers.get_xr_controller(self):
		warnings.append("This node must be within a branch of an XRController3D node")
	return warnings
