extends Node
# Coup de poing du gorille (VR) : il faut FRAPPER, un simple contact ne casse rien.
# Un coup = la main part vite (par rapport au joueur) et touche un objet cassable.
# Les cibles implémentent on_smashed_at(point, normal, impulse) ou on_smashed(impulse).
# À attacher en enfant de chaque manette (comme avant) ; PlayerXR le active avec "enabled".

@export var enabled := false
@export var smash_force := 15.0
@export var min_punch_speed := 3.0   # vitesse mini de la main en m/s : en dessous, simple contact
@export var reach := 0.3             # distance devant la main où un coup porte (m)
@export var cooldown := 0.4          # délai entre deux coups (s)
@export var debug := false           # affiche la vitesse de la main et ce qu'elle touche

@onready var hand: XRController3D = get_parent()

var _prev_pos := Vector3.ZERO
var _has_prev := false
var _velocity := Vector3.ZERO        # vitesse de la main par rapport au joueur (repère monde)
var _cooldown_left := 0.0
var _debug_timer := 0.0


func _physics_process(delta: float) -> void:
	# Vitesse de la main par rapport au rig : on ignore le déplacement du joueur au joystick
	var pos := hand.position
	if _has_prev and delta > 0.0:
		var local_velocity := (pos - _prev_pos) / delta
		var origin := hand.get_parent() as Node3D
		var world_velocity := (origin.global_basis * local_velocity) if origin else local_velocity
		_velocity = _velocity.lerp(world_velocity, 0.6)     # lisse le bruit du suivi
	_prev_pos = pos
	_has_prev = true

	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	var speed := _velocity.length()

	if debug and enabled:
		_debug_timer -= delta
		if speed > min_punch_speed * 0.5 and _debug_timer <= 0.0:
			_debug_timer = 0.25
			print("[Smash] vitesse main = %.1f m/s (seuil %.1f)" % [speed, min_punch_speed])

	if not enabled or _cooldown_left > 0.0 or speed < min_punch_speed:
		return
	_try_hit(_velocity / speed)


func _try_hit(dir: Vector3) -> void:
	var from := hand.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * reach, 1)   # couche 1 : le décor
	var result := hand.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return

	var target: Object = result["collider"]
	var point: Vector3 = result["position"]
	var normal: Vector3 = result["normal"]
	var impulse := dir * smash_force
	if debug:
		print("[Smash] coup sur : ", target)

	if target.has_method("on_smashed_at"):
		target.on_smashed_at(point, normal, impulse)
	elif target.has_method("on_smashed"):
		target.on_smashed(impulse)
	else:
		return      # surface non cassable : pas de coup, pas de vibration

	_cooldown_left = cooldown
	hand.trigger_haptic_pulse("haptic", 0.0, 1.0, 0.2, 0.0)
