extends Node

@export var enabled := false
@export var smash_force := 15.0
@export var smash_range := 2.5
#pour casser le mur avec la main 
#@export var velocity_threshold := 3.0

@onready var hand: XRController3D = get_parent()
@onready var ray: RayCast3D = $SmashRay
@onready var camera: XRCamera3D = XRHelpers.get_xr_camera(self)

#pour casser le mur avec la main 
#var _last_position := Vector3.ZERO


func _ready() -> void:
	ray.target_position = Vector3(0.0, 0.0, -smash_range)
	hand.button_pressed.connect(_on_button)
	#pour casser le mur avec la main 
	#if hand:
	#	_last_position = hand.global_position

#func _physics_process(delta: float) -> void:
	#if not enabled or delta == 0.0:
		#return
#
	## 1. Calculer la vitesse actuelle du contrôleur VR (distance parcourue / temps)
	#var current_position := hand.global_position
	#var velocity := (current_position - _last_position) / delta
	#_last_position = current_position
#
	## 2. Vérifier si le joueur donne un coup de poing (mouvement rapide vers l'avant ou dans l'espace)
	## On peut aussi filtrer par la direction du regard ou du contrôleur si besoin
	#if velocity.length() < velocity_threshold:
		#return
#
	## 3. Mettre à jour le RayCast depuis la main ou la caméra pour toucher la porte
	#ray.global_position = current_position
	## Oriente le raycast selon l'orientation du contrôleur (ou de sa direction de mouvement)
	#ray.global_transform.basis = hand.global_transform.basis
	#
	#ray.force_raycast_update()
	#if not ray.is_colliding():
		#return
#
	#var target := ray.get_collider()
	#if target and target.has_method("on_smashed"):
		## On transmet la vitesse du poing comme impulsion pour éjecter les éclats de bois
		#var smash_dir = velocity.normalized()
		#target.on_smashed(smash_dir * smash_force)

func _on_button(button: String) -> void:
	if not enabled or button != "trigger_click":
		return
	if camera:
		var forward := -camera.global_transform.basis.z
		ray.global_position = camera.global_position
		ray.look_at(camera.global_position + forward, Vector3.UP)
	ray.force_raycast_update()
	if not ray.is_colliding():
		return
	var target := ray.get_collider()
	if target and target.has_method("on_smashed"):
		var origin := camera.global_position if camera else hand.global_position
		target.on_smashed(origin.direction_to(ray.get_collision_point()) * smash_force)
