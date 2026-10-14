# Door.gd
class_name SlidingDoor
extends AnimatableBody3D

@export var open_offset: Vector3 = Vector3(0, 2.5, 0) # Déplacement vers le haut
@export var move_duration: float = 0.8

@onready var closed_position: Vector3 = position
@onready var open_position: Vector3 = position + open_offset

var tween: Tween

func open() -> void:
	_animate_to(open_position, Tween.EASE_OUT)

func close() -> void:
	_animate_to(closed_position, Tween.EASE_IN)

func _animate_to(target_pos: Vector3, ease_type: Tween.EaseType) -> void:
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(ease_type)
	tween.tween_property(self, "position", target_pos, move_duration)
