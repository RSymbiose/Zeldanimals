class_name SlidingDoor
extends AnimatableBody3D

# Angle d'ouverture autour de l'axe Y, en degrés.
# Positif = sens inverse des aiguilles d'une montre vu de dessus, négatif = l'inverse.
@export var open_angle_degrees: float = 90.0
@export var move_duration: float = 0.8

@onready var closed_rotation_y: float = rotation.y 
@onready var open_rotation_y: float = closed_rotation_y + deg_to_rad(open_angle_degrees)


var current_angle = self.rotation.y

var target_angle = deg_to_rad(0.0) # Angle cible (ex: porte fermée)
var shortest_target = current_angle + angle_difference(current_angle, target_angle)
var tween: Tween

func open() -> void:
	_animate_to(open_rotation_y, Tween.EASE_OUT)

func close() -> void:
	_animate_to(closed_rotation_y, Tween.EASE_IN)

func _animate_to(target_rotation_y: float, ease_type: Tween.EaseType) -> void:
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(ease_type)
	tween.tween_property(self, "rotation:y", shortest_target, 0.8)\

	.set_trans(Tween.TRANS_QUAD)\

	.set_ease(Tween.EASE_OUT)


func _on_pressure_plate_pressed() -> void:
	pass # Replace with function body.
