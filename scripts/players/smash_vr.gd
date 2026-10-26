extends Node

@export var enabled := false
@export var smash_force := 15.0
@export var smash_range := 2.5

@onready var hand: XRController3D = get_parent()
@onready var ray: RayCast3D = $SmashRay


func _ready() -> void:
	ray.target_position = Vector3(0.0, 0.0, -smash_range)
	hand.button_pressed.connect(_on_button)


func _on_button(button: String) -> void:
	if not enabled or button != "trigger_click":
		return
	ray.force_raycast_update()
	if not ray.is_colliding():
		return
	var target := ray.get_collider()
	if target and target.has_method("on_smashed"):
		target.on_smashed(hand.global_position.direction_to(ray.get_collision_point()) * smash_force)