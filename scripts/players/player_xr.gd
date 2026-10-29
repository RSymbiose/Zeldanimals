class_name PlayerXR
extends XROrigin3D

signal form_changed(form: String)

@export_enum("human", "gorilla", "chicken", "spider") var start_form := "spider"

const FORMS := ["human", "gorilla", "chicken", "spider"]

# Réglages par animal : taille (world_scale) et vitesse de saut
const FORM_DATA := {
	"human":   {"scale": 1.0, "jump": 4.5},
	"gorilla": {"scale": 1.3, "jump": 10.0},
	"chicken": {"scale": 0.8, "jump": 5.0},
	"spider":  {"scale": 0.5, "jump": 4.5},
}

# Distance (en mètres) dont le corps est reculé par rapport à la tête,
# pour que la tête du modèle ne bouche pas la vue
const BODY_BACK_OFFSET := 0.25
const BODY_MODEL_HEIGHT_OFFSET := 0.8
const CLIMB_CAMERA_PITCH := PI * 0.5
const CLIMB_CAMERA_TURN_SPEED := 5.0

@onready var camera: XRCamera3D = $XRCamera3D
@onready var left_hand: XRController3D = $LeftHand
@onready var right_hand: XRController3D = $RightHand

@onready var jump: Node = $RightHand/XRToolsMovementJump
@onready var glide: Node = $RightHand/XRToolsMovementGlide
@onready var grapple: Node = $RightHand/XRToolsMovementGrapple
@onready var grapple_ray: RayCast3D = $RightHand/XRToolsMovementGrapple/Grapple_RayCast
@onready var auto_wall_climb: Node = $LeftHand/SpiderAutoWallClimb
@onready var smash: Node = $RightHand/SmashVR
@onready var climb_left: Node = $LeftHand/XRToolsMovementClimb
@onready var climb_right: Node = $LeftHand/XRToolsMovementClimb

@onready var landing: Node = $LandingEffect
@onready var player_body: XRToolsPlayerBody = get_node_or_null("PlayerBody") as XRToolsPlayerBody

# Modèles 3D : un Node3D par animal, nommé "gorilla", "chicken", "spider"
@onready var body_models: Node3D = $BodyModels
# Ponte d'œuf (enfant de BodyModels/chicken) ; reste null s'il n'existe pas encore
@onready var chicken_mech: ChickenMechanics = get_node_or_null("BodyModels/chicken/ChickenMechanics") as ChickenMechanics

# Formes que le joueur a le droit de prendre.
# Vide = toutes sauf "human" (comportement d'origine). Le PlayerSpawner peut la remplir.
var unlocked_forms: Array[String] = []

var current_form := ""
var _camera_pitch_initialized := false
var _camera_base_pitch := 0.0
var _camera_applied_pitch := 0.0


func _ready() -> void:
	add_to_group("player_forms")   # permet aux potions de retrouver le joueur

	# Sécurité : chaque main suit bien sa manette
	left_hand.tracker = &"left_hand"
	right_hand.tracker = &"right_hand"

	left_hand.button_pressed.connect(_on_left_button)
	switch_to(start_form)


func _process(_delta: float) -> void:
	_update_grapple_aim()
	_update_climb_view(_delta)
	# Le corps de l'animal suit la tête (position et rotation horizontales)
	if body_models == null:
		return
	var yaw := camera.rotation.y
	var back := Vector3(sin(yaw), 0.0, cos(yaw)) * BODY_BACK_OFFSET
	body_models.position = Vector3(
		camera.position.x,
		camera.position.y - BODY_MODEL_HEIGHT_OFFSET,
		camera.position.z) + back
	body_models.rotation.y = yaw


func _update_grapple_aim() -> void:
	if right_hand == null or grapple_ray == null:
		return
	# Le rayon part de la manette droite et pointe dans la direction où pointe la manette
	grapple_ray.global_position = right_hand.global_position
	var forward := -right_hand.global_transform.basis.z
	grapple_ray.look_at(right_hand.global_position + forward, Vector3.UP)


func _update_climb_view(delta: float) -> void:
	if camera == null:
		return
	if not _camera_pitch_initialized:
		_camera_base_pitch = camera.rotation.x
		_camera_applied_pitch = camera.rotation.x
		_camera_pitch_initialized = true
	else:
		# XR Simulator modifies the camera directly. Preserve that input as the
		# player's pitch before applying the climbing-only offset.
		_camera_base_pitch += camera.rotation.x - _camera_applied_pitch
	var is_climbing := current_form == "spider" and (
		bool(_get_prop(auto_wall_climb, "is_active"))
		or bool(_get_prop(climb_left, "is_active"))
		or bool(_get_prop(climb_right, "is_active")))
	var target_offset := CLIMB_CAMERA_PITCH if is_climbing else 0.0
	var current_offset := _camera_applied_pitch - _camera_base_pitch
	var next_offset := move_toward(current_offset, target_offset, CLIMB_CAMERA_TURN_SPEED * delta)
	_camera_applied_pitch = _camera_base_pitch + next_offset
	camera.rotation.x = _camera_applied_pitch


func _on_left_button(button: String) -> void:
	match button:
		# Bouton Y (manette gauche) : forme suivante
		"by_button":
			var available := _available_forms()
			if available.size() > 1:
				var next: int = (available.find(current_form) + 1) % available.size()
				switch_to(available[next])
		# Gâchette gauche : la poule pond un œuf
		"trigger_click":
			if current_form == "chicken" and chicken_mech:
				chicken_mech.lay_egg()


# Formes accessibles avec le bouton Y
func _available_forms() -> Array:
	var out := []
	for f in FORMS:
		if unlocked_forms.is_empty():
			if f != "human":
				out.append(f)
		elif f in unlocked_forms:
			out.append(f)
	return out


# Débloque une forme (potion, bonus...) et, par défaut, s'y transforme tout de suite
func unlock_form(form: String, switch_now := true) -> void:
	if not unlocked_forms.is_empty() and not (form in unlocked_forms):
		unlocked_forms.append(form)
	if switch_now:
		switch_to(form)


func switch_to(form: String) -> void:
	if form == current_form or not FORM_DATA.has(form):
		return
	
	var previous_form = current_form
	var first_time: bool = (previous_form == "")
	current_form = form

	var data: Dictionary = FORM_DATA[form]
	
	# Calcul d'un décalage vertical proportionnel pour éviter de passer à travers le sol ou de flotter
	var height_adjustment := 0.0
	if not first_time and FORM_DATA.has(previous_form):
		# Si on passe à un gorille, on le surélève généreusement pour éviter qu'il traverse le sol
		if form == "gorilla":
			height_adjustment = 2.0
		else:
			var prev_scale = FORM_DATA[previous_form]["scale"]
			var new_scale = data["scale"]
			height_adjustment = (new_scale - prev_scale) * 0.35

	_apply_scale(data["scale"], not first_time, height_adjustment)
	
	if player_body and player_body.default_physics:
		player_body.default_physics.jump_velocity = data["jump"]

	# On n'active que les capacités de l'animal courant
	_enable(smash, form == "gorilla")
	_enable(glide, form == "chicken")
	_enable(grapple, form == "spider")
	_enable(auto_wall_climb, form == "spider")
	_enable(climb_left, form == "spider")
	_enable(climb_right, form == "spider")
	_enable(landing, form == "gorilla")

	# Retour visuel et tactile
	_show_body_model(form)
	if not first_time:
		_haptic_feedback(form)

	form_changed.emit(form)


func _apply_scale(target: float, is_switch: bool, height_offset: float = 0.3) -> void:
	world_scale = target
	if not is_switch:
		return

	# On ajuste la hauteur avec le décalage calculé pour ne pas s'enfoncer dans le sol
	var xf := global_transform
	xf.origin.y += height_offset
	if player_body and player_body.has_method("teleport"):
		player_body.teleport(xf)
	else:
		global_transform = xf
	_set_prop(player_body, "velocity", Vector3.ZERO)


func _show_body_model(form: String) -> void:
	if body_models == null:
		return
	for m in body_models.get_children():
		if m is Node3D:
			m.visible = (m.name == form)


func _haptic_feedback(form: String) -> void:
	# Le gorille vibre plus fort que les autres
	var amplitude := 1.0 if form == "gorilla" else 0.5
	for hand in [left_hand, right_hand]:
		hand.trigger_haptic_pulse("haptic", 0.0, amplitude, 0.3, 0.0)


func _enable(node: Node, value: bool) -> void:
	_set_prop(node, "enabled", value)


func _set_prop(node: Node, prop: String, value: Variant) -> void:
	if node == null:
		return
	node.set(prop, value)


func _get_prop(node: Node, prop: String) -> Variant:
	if node == null:
		return false
	return node.get(prop)
