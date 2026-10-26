# PressurePlate.gd
class_name PressurePlate
extends Area3D

signal pressed
signal released

var overlapping_bodies: Array[Node3D] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	# N'accepte que le joueur (CharacterBody3D) et les objets physiques (RigidBody3D)
	if not (body is CharacterBody3D or body is RigidBody3D):
		return

	if not overlapping_bodies.has(body):
		overlapping_bodies.append(body)
		# Sécurité : si l'oeuf disparaît (queue_free) posé sur la plaque
		body.tree_exiting.connect(_on_body_tree_exiting.bind(body), CONNECT_ONE_SHOT)

		if overlapping_bodies.size() == 1:
			pressed.emit()

func _on_body_exited(body: Node3D) -> void:
	_remove_body(body)

func _on_body_tree_exiting(body: Node3D) -> void:
	_remove_body(body)

func _remove_body(body: Node3D) -> void:
	if overlapping_bodies.has(body):
		overlapping_bodies.erase(body)
		if overlapping_bodies.is_empty():
			released.emit()
