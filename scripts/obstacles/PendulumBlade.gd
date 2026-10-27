class_name PendulumBlade
extends AnimatableBody3D

@export var max_angle_deg: float = 65.0           # Angle max d'oscillation
@export var swing_speed: float = 2.2              # Vitesse de balancement (pulsation)
@export var initial_phase: float = 0.0            # Déphasage (0 à PI) pour désynchroniser des pendules
@export var swing_axis: Vector3 = Vector3.FORWARD # Axe de rotation (Z par défaut)

var time_elapsed: float = 0.0
var max_angle_rad: float = 0.0

@onready var hit_area: Area3D = $HitArea

func _ready() -> void:
	max_angle_rad = deg_to_rad(max_angle_deg)
	time_elapsed = initial_phase
	
	if hit_area:
		hit_area.body_entered.connect(_on_hit_area_body_entered)

func _physics_process(delta: float) -> void:
	time_elapsed += delta

	# Calcul de l'angle theta(t) = theta_max * sin(omega * t)
	var current_angle: float = sin(time_elapsed * swing_speed) * max_angle_rad

	# Rotation calculée sur l'axe choisi
	basis = Basis(swing_axis.normalized(), current_angle)

func _on_hit_area_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		# Direction de propulsion latérale perpendiculaire au pendule
		var knockback_dir: Vector3 = global_transform.basis.x.normalized()
		if body.has_method("take_hit"):
			body.take_hit(knockback_dir * 8.0)
