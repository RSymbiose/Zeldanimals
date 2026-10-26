extends Node3D

@export var enabled := false
@export var web_range := 20.0
@export var pull_speed := 10.0

@onready var hand: XRController3D = get_parent()
@onready var ray: RayCast3D = $WebRay
@onready var body: XRToolsPlayerBody = get_tree().get_first_node_in_group("player_body")

var point := Vector3.ZERO
var active := false


func _ready() -> void:
	ray.target_position = Vector3(0, 0, -web_range)
	hand.button_pressed.connect(_on_button_pressed)
	hand.button_released.connect(_on_button_released)


func _on_button_pressed(button: String) -> void:
	if enabled and button == "trigger_click":
		_start()


func _on_button_released(button: String) -> void:
	if button == "trigger_click":
		active = false


func _start() -> void:
	ray.force_raycast_update()
	if ray.is_colliding():
		point = ray.get_collision_point()
		active = true


func _physics_process(_delta: float) -> void:
	if not enabled or not active or body == null:
		return
	var dir := point - hand.global_position
	if dir.length() < 1.5:
		active = false
		return
	body.velocity = dir.normalized() * pull_speed