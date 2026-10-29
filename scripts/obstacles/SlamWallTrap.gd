# SlamWallTrap.gd
class_name SlamWallTrap
extends Node3D

@export var slam_distance: float = 3.5        # Portée de sortie du bloc (mètres)
@export var slam_duration: float = 0.12       # Vitesse de jaillissement (éclair)
@export var retract_duration: float = 2.0     # Vitesse de retrait dans le mur
@export var reset_delay: float = 1.0          # Temps de maintien en position sortie
@export var knockback_force: float = 20.0     # Vélocité transmise à l'impact
@export var slam_direction: Vector3 = Vector3.RIGHT # Direction locale d'éjection

@onready var slam_block: AnimatableBody3D = $SlamBlock
@onready var trigger_area: Area3D = $TriggerArea
@onready var hit_area: Area3D = $SlamBlock/HitArea

var _initial_pos: Vector3
var _is_triggered: bool = false

func _ready() -> void:
	_initial_pos = slam_block.position
	
	# Obligatoire pour le calcul de collision cinématique
	slam_block.sync_to_physics = true

	trigger_area.body_entered.connect(_on_trigger_body_entered)
	if hit_area:
		hit_area.body_entered.connect(_on_hit_body_entered)

func _on_trigger_body_entered(body: Node3D) -> void:
	if _is_triggered or not (body is CharacterBody3D):
		return
	_execute_slam()

func _execute_slam() -> void:
	_is_triggered = true

	var target_pos: Vector3 = _initial_pos + (slam_direction.normalized() * slam_distance)

	# Création d'un Tween synchronisé sur la physique
	var tween: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)

	# 1. Éjection ultra-brutale vers l'avant (accélération rapide)
	tween.tween_property(slam_block, "position", target_pos, slam_duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)

	# 2. Maintien en position déployée
	tween.tween_interval(reset_delay)

	# 3. Rentrée lente dans le mur
	tween.tween_property(slam_block, "position", _initial_pos, retract_duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	await tween.finished
	_is_triggered = false

func _on_hit_body_entered(body: Node3D) -> void:
	# Sanction supplémentaire si la méthode apply_knockback est prête
	if body is CharacterBody3D and body.has_method("apply_knockback"):
		var punch_vector: Vector3 = global_transform.basis * slam_direction.normalized()
		var impulse: Vector3 = (punch_vector * knockback_force) + (Vector3.UP * 6.0)
		body.apply_knockback(impulse)
