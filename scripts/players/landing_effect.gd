extends Node
# LandingEffect : le gorille est LOURD -> sa vue "tape" le sol à l'atterrissage.
#  - PC  : la CAMERA s'enfonce brièvement puis remonte avec un petit rebond
#          (ressort amorti). Aucun bord sombre, aucun tremblement aléatoire.
#  - VR  : courte vibration des manettes (on ne bouge JAMAIS la caméra en VR).
#
# PC : ce nœud est enfant de "Gorilla". Le champ Camera peut rester vide :
#      la Camera3D du gorille est retrouvée automatiquement.
# VR : ce nœud est enfant de PlayerXR, champ Body = PlayerBody,
#      champs Left Hand / Right Hand = les deux manettes.

@export var enabled := true
@export var body: CharacterBody3D        # par défaut : le parent
@export var camera: Camera3D             # PC seulement (auto si vide)
@export var left_hand: XRController3D    # VR seulement
@export var right_hand: XRController3D   # VR seulement

@export_group("Réglages")
@export var min_fall_speed := 3.0        # en dessous : aucun effet
@export var max_fall_speed := 14.0       # à partir de là : effet maximal
@export var impact_speed := 1.2          # force de l'enfoncement (PC)
@export var stiffness := 150.0           # raideur du ressort : plus grand = plus sec
@export var damping := 12.0              # amortissement : plus petit = plus de rebonds
@export var haptic_scale := 0.6          # intensité de la vibration (VR)

var _was_on_floor := true
var _fall_peak := 0.0          # vitesse de chute max pendant le vol (négative)
var _camera_rest := Vector3.ZERO
var _offset := 0.0
var _offset_vel := 0.0
var _active := false


func _ready() -> void:
	if body == null:
		body = get_parent() as CharacterBody3D
	if camera == null:
		camera = get_parent().find_child("Camera3D", true, false) as Camera3D
	if camera is XRCamera3D:
		camera = null            # jamais de secousse sur la caméra VR
	print("LandingEffect: caméra = ", camera, " | corps = ", body)


func _physics_process(_delta: float) -> void:
	if body == null:
		return
	var on_floor := body.is_on_floor()
	if not on_floor:
		_fall_peak = minf(_fall_peak, body.velocity.y)
	else:
		if not _was_on_floor and enabled:
			var speed := -_fall_peak
			if speed >= min_fall_speed:
				_play(inverse_lerp(min_fall_speed, max_fall_speed, speed))
		_fall_peak = 0.0
	_was_on_floor = on_floor


func _process(delta: float) -> void:
	if camera == null or not _active:
		return
	# Ressort amorti : la caméra est poussée vers le bas puis revient à sa place
	var accel := -stiffness * _offset - damping * _offset_vel
	_offset_vel += accel * delta
	_offset += _offset_vel * delta
	camera.position.y = _camera_rest.y + _offset

	if absf(_offset) < 0.0005 and absf(_offset_vel) < 0.005:
		_offset = 0.0
		_offset_vel = 0.0
		camera.position.y = _camera_rest.y
		_active = false


func _play(strength: float) -> void:
	strength = clampf(strength, 0.3, 1.0)

	if camera:
		if not _active:
			_camera_rest = camera.position     # position de repos au moment du choc
		_offset_vel = -strength * impact_speed  # coup vers le bas
		_active = true

	for hand in [left_hand, right_hand]:
		if hand:
			hand.trigger_haptic_pulse("haptic", 0.0, strength * haptic_scale, 0.15, 0.0)
