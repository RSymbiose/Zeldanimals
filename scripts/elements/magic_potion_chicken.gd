class_name MagicPotionChicken
extends Node3D
# Potion qui lévite et brille. Quand le joueur la boit, il se transforme.
#  - PC : approche-toi, regarde la potion et appuie sur E.
#  - VR : attrape-la avec la gâchette de poigne (grip) et approche-la de ta bouche.
#
# Structure de la scène :
#   MagicPotion (Node3D, ce script)
#    └─ la bouteille (le modèle 3D, instance du .gltf)
# La lumière, l'aura brillante et le texte d'aide sont créés par le script.

signal drunk

@export_enum("gorilla", "chicken", "spider") var form_to_unlock := "chicken"
@export var debug := false                   # affiche l'état de la potion dans la console chaque seconde

@export_group("Lévitation et éclat")
@export var float_height := 0.08            # amplitude du va-et-vient vertical (m)
@export var spin_speed := 1.0               # rotation de la bouteille (rad/s)
@export var glow_color := Color(0.3, 1.0, 0.5)

@export_group("PC")
@export var interact_range := 2.0           # distance max pour boire (m)
@export var look_threshold := 0.6           # 1 = bien en face, 0 = de côté

@export_group("VR")
@export var grab_action := "grip_click"     # bouton pour attraper
@export var grab_range := 0.35              # distance main-bouteille pour l'attraper (m)
@export var drink_range := 0.3              # distance bouteille-tête pour la boire (m)

var _model: Node3D
var _rest := Vector3.ZERO
var _t := 0.0
var _drunk := false
var _can_interact := false

var _light: OmniLight3D
var _prompt: Label3D
var _aura: StandardMaterial3D

var _hands: Array[XRController3D] = []
var _grabbed_by: XRController3D = null
var _scan_timer := 0.0
var _release_from := Vector3.ZERO
var _return_t := 1.0
var _debug_timer := 0.0


func _ready() -> void:
	for child in get_children():
		if child is Node3D:
			_model = child
			break
	if _model == null:
		push_error("MagicPotion : ajoute le modèle de la bouteille comme enfant.")
		set_process(false)
		set_process_unhandled_input(false)
		return
	_rest = _model.position
	if debug:
		print("[Potion] prête. Modèle = ", _model.name, " | position monde = ", _model.global_position)

	# Action "interact" (touche E) créée si elle n'existe pas
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_E
		InputMap.action_add_event("interact", key)

	_build_glow()


func _process(delta: float) -> void:
	if _drunk:
		return
	_t += delta
	_debug_print(delta)
	_animate(delta)
	_light.light_energy = 1.5 + sin(_t * 3.0) * 0.4
	_aura.albedo_color.a = 0.3 + sin(_t * 3.0) * 0.12

	if _is_vr():
		_process_vr(delta)
	else:
		_process_pc()


func _unhandled_input(event: InputEvent) -> void:
	if _can_interact and not _drunk and event.is_action_pressed("interact"):
		_drink()


# ------------------------------------------------------------------ Animation

func _animate(delta: float) -> void:
	if _grabbed_by != null:
		return
	var target := _rest + Vector3(0, sin(_t * 1.6) * float_height, 0)
	if _return_t < 1.0:                      # retour en douceur après un lâcher
		_return_t = minf(_return_t + delta * 2.0, 1.0)
		_model.position = _release_from.lerp(target, _return_t)
	else:
		_model.position = target
	_model.rotate_y(spin_speed * delta)


func _build_glow() -> void:
	# Aura : le mesh est redessiné légèrement agrandi, en additif
	_aura = StandardMaterial3D.new()
	_aura.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aura.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_aura.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_aura.cull_mode = BaseMaterial3D.CULL_FRONT
	_aura.grow = true
	_aura.grow_amount = 0.01
	_aura.albedo_color = Color(glow_color, 0.4)

	var meshes: Array[Node] = _model.find_children("*", "MeshInstance3D", true, false)
	if _model is MeshInstance3D:
		meshes.append(_model)
	for node in meshes:
		(node as MeshInstance3D).material_overlay = _aura

	# Lumière qui éclaire la pièce autour de la bouteille
	_light = OmniLight3D.new()
	_light.light_color = glow_color
	_light.omni_range = 3.0
	_light.light_energy = 1.5
	add_child(_light)
	_light.position = _rest + Vector3(0, 0.1, 0)

	# Texte d'aide, visible quand on est assez proche
	_prompt = Label3D.new()
	_prompt.text = "Attrape la potion (grip)\net approche-la de ta bouche" if _is_vr() else "[E] Boire la potion"
	_prompt.font_size = 48
	_prompt.pixel_size = 0.0015
	_prompt.outline_size = 10
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.visible = false
	add_child(_prompt)
	_prompt.position = _rest + Vector3(0, 0.45, 0)


# ------------------------------------------------------------------ PC

func _process_pc() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		_can_interact = false
		_prompt.visible = false
		return
	var to_bottle := _model.global_position - cam.global_position
	var near := to_bottle.length() < interact_range
	var looking := (-cam.global_basis.z).dot(to_bottle.normalized()) > look_threshold
	_can_interact = near and looking
	_prompt.visible = _can_interact


# ------------------------------------------------------------------ VR

func _process_vr(delta: float) -> void:
	_find_hands(delta)
	var cam := get_viewport().get_camera_3d()

	if _grabbed_by != null:
		_model.global_position = _grabbed_by.global_position
		if cam and cam.global_position.distance_to(_model.global_position) < drink_range:
			_drink()
		return

	var near := false
	for hand in _hands:
		if hand.global_position.distance_to(_model.global_position) < grab_range * 2.0:
			near = true
	_prompt.visible = near


# Les manettes n'existent qu'une fois le joueur créé par le PlayerSpawner : on les cherche au fil de l'eau
func _find_hands(delta: float) -> void:
	if _hands.size() >= 2:
		return
	_scan_timer -= delta
	if _scan_timer > 0.0:
		return
	_scan_timer = 0.5
	for node in get_tree().root.find_children("*", "XRController3D", true, false):
		var hand := node as XRController3D
		if hand in _hands:
			continue
		_hands.append(hand)
		hand.button_pressed.connect(_on_hand_pressed.bind(hand))
		hand.button_released.connect(_on_hand_released.bind(hand))


func _on_hand_pressed(action_name: String, hand: XRController3D) -> void:
	if debug:
		print("[Potion] bouton pressé : '%s' (attendu : '%s') | distance main-bouteille = %.2f m (max %.2f)" % [
			action_name, grab_action, hand.global_position.distance_to(_model.global_position), grab_range])
	if _drunk or action_name != grab_action or _grabbed_by != null:
		return
	if hand.global_position.distance_to(_model.global_position) <= grab_range:
		_grabbed_by = hand
		_prompt.visible = false
		hand.trigger_haptic_pulse("haptic", 0.0, 0.4, 0.1, 0.0)


func _on_hand_released(action_name: String, hand: XRController3D) -> void:
	if hand == _grabbed_by and action_name == grab_action:
		_grabbed_by = null
		_release_from = _model.position
		_return_t = 0.0                       # la bouteille retourne léviter à sa place


# ------------------------------------------------------------------ Boire

func _drink() -> void:
	if _drunk:
		return
	_drunk = true
	_prompt.visible = false

	var player := get_tree().get_first_node_in_group("player_forms")
	var checkpoint := _player_transform(player)   # position AVANT la transformation
	if player and player.has_method("unlock_form"):
		player.unlock_form(form_to_unlock, true)
	else:
		push_warning("MagicPotion : aucun joueur trouvé (groupe 'player_forms').")
	_save_checkpoint(checkpoint)

	drunk.emit()
	_play_effect()

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_model, "scale", Vector3.ZERO, 0.25)
	tween.tween_property(_light, "light_energy", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)


func _play_effect() -> void:
	for hand in _hands:
		hand.trigger_haptic_pulse("haptic", 0.0, 1.0, 0.5, 0.0)
	if _is_vr():
		return    # un écran 2D n'est pas visible dans un casque

	# PC : flash coloré qui s'estompe
	var layer := CanvasLayer.new()
	layer.layer = 98
	var flash := ColorRect.new()
	flash.color = Color(glow_color, 0.85)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(flash)
	get_tree().current_scene.add_child(layer)
	var tween := layer.create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.8)
	tween.tween_callback(layer.queue_free)


func _debug_print(delta: float) -> void:
	if not debug:
		return
	_debug_timer -= delta
	if _debug_timer > 0.0:
		return
	_debug_timer = 1.0

	var cam := get_viewport().get_camera_3d()
	var player := get_tree().get_first_node_in_group("player_forms")
	var info := "[Potion] VR=%s | caméra=%s | joueur(groupe player_forms)=%s" % [_is_vr(), cam != null, player]
	if cam:
		var to_bottle := _model.global_position - cam.global_position
		info += " | distance=%.2f m (max %.1f)" % [to_bottle.length(), interact_range]
		info += " | regard=%.2f (min %.1f)" % [(-cam.global_basis.z).dot(to_bottle.normalized()), look_threshold]
	if _is_vr():
		info += " | manettes trouvées=%d | bouteille tenue=%s" % [_hands.size(), _grabbed_by != null]
	else:
		info += " | peut boire=%s" % _can_interact
	print(info)


# Où se trouve le joueur (au sol, orienté comme sa tête) : ce sera son point de réapparition
func _player_transform(player: Node) -> Transform3D:
	if player == null:
		return global_transform
	# PC : le corps actif du FormSwitcher
	var current = player.get("current")
	if current is Node3D:
		return (current as Node3D).global_transform
	# VR : au sol, sous la tête
	if player is Node3D:
		var rig := player as Node3D
		var cam := get_viewport().get_camera_3d()
		if cam:
			var feet := Vector3(cam.global_position.x, rig.global_position.y, cam.global_position.z)
			return Transform3D(Basis.from_euler(Vector3(0.0, cam.global_rotation.y, 0.0)), feet)
		return rig.global_transform
	return global_transform


func _save_checkpoint(xf: Transform3D) -> void:
	var spawner := get_tree().get_first_node_in_group("player_spawner")
	if spawner and spawner.has_method("set_checkpoint"):
		spawner.set_checkpoint(xf)
	else:
		push_warning("MagicPotion : aucun PlayerSpawner trouvé (groupe 'player_spawner'), pas de point de réapparition.")


func _is_vr() -> bool:
	var manager := get_node_or_null("/root/PlatformManager")
	return manager != null and manager.is_vr
