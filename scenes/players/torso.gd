# ChickenTorso.gd
class_name ChickenTorso
extends Node3D

@export var xr_camera: XRCamera3D
@export var neck_angle_limit: float = deg_to_rad(45.0) # Seuil avant rotation du torse (±45°)
@export var body_turn_speed: float = 6.0              # Réactivité du suivi angulaire
@export var torso_floor_offset_y: float = 0.15         # Hauteur du torse au-dessus du sol de l'XROrigin3D

func _ready() -> void:
	# Résolution automatique de la caméra si non assignée dans l'inspecteur
	if xr_camera == null:
		xr_camera = get_parent().get_node_or_null("XRCamera3D")

func _process(delta: float) -> void:
	if xr_camera == null or not get_viewport().use_xr:
		return

	# 1. SUIVI PHYSIQUE ROOMSCALE (Translation X et Z uniquement)
	# Le corps reste sous la tête du joueur quand il marche dans sa pièce
	position.x = xr_camera.position.x
	position.z = xr_camera.position.z
	position.y = torso_floor_offset_y

	# 2. SUIVI ANGULAIRE AVEC ZONE MORTE (Lacet / Yaw)
	var head_yaw: float = xr_camera.rotation.y
	var torso_yaw: float = rotation.y

	# Calcul de l'écart angulaire le plus direct sur [-PI, PI]
	var angle_diff: float = wrapf(head_yaw - torso_yaw, -PI, PI)

	# Si la rotation de la tête dépasse la flexibilité du cou
	if abs(angle_diff) > neck_angle_limit:
		var target_yaw: float = head_yaw - (sign(angle_diff) * neck_angle_limit)
		rotation.y = lerp_angle(torso_yaw, target_yaw, body_turn_speed * delta)
