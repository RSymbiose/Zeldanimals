class_name PendulumBlade
extends AnimatableBody3D

@export var max_angle_deg: float = 65.0           # Angle max d'oscillation
@export var swing_speed: float = 2.2              # Vitesse de balancement (pulsation)
@export var initial_phase: float = 0.0            # Déphasage (0 à PI) pour désynchroniser des pendules
@export var swing_axis: Vector3 = Vector3.FORWARD # Axe de rotation (Z par défaut)
@export var knockback_force: float = 16.0 # Vitesse d'éjection horizontale (m/s)
@export var upward_force: float = 8.0     # Impulsion verticale pour décoller du sol (m/s)

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
	if body is CharacterBody3D and body.has_method("apply_knockback"):
		# 1. Calcul du sens instantané de déplacement de la lame (dérivée du sinus)
		var angular_velocity_sign: float = sign(cos(time_elapsed * swing_speed))
		if angular_velocity_sign == 0.0:
			angular_velocity_sign = 1.0

		# 2. Vecteur tangentiel horizontal selon l'axe de balancement
		var swing_direction: Vector3 = (global_transform.basis.x * angular_velocity_sign).normalized()

		# 3. Composition de l'impulsion (éjection latérale + propulsion en l'air)
		var impulse: Vector3 = (swing_direction * knockback_force) + (Vector3.UP * upward_force)
		
		body.apply_knockback(impulse)
