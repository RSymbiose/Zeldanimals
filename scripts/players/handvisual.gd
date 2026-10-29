class_name HandVisuals
extends Node
# Affiche des mains sur les deux manettes du joueur VR (sinon, des manettes simplifiées).
# Ajouté automatiquement par PlayerXR (add_child(HandVisuals.new())).
# Il s'attend à trouver "LeftHand" et "RightHand" (des XRController3D) dans le rig.
#
# Les mains de XR Tools suivent la manette et bougent leurs doigts avec la gâchette et le grip.
# La couleur change avec la forme : peau pour l'humain, noir pour le gorille, etc.

const LEFT_HAND_PATH := "res://addons/godot-xr-tools/hands/scenes/lowpoly/left_hand_low.tscn"
const RIGHT_HAND_PATH := "res://addons/godot-xr-tools/hands/scenes/lowpoly/right_hand_low.tscn"

const SKIN_COLORS := {
	"human": Color(0.92, 0.72, 0.58),
	"gorilla": Color(0.16, 0.15, 0.16),
	"chicken": Color(0.96, 0.86, 0.5),
	"spider": Color(0.2, 0.2, 0.26),
}

@export var use_xr_tools_hands := true   # false = manettes simplifiées
@export var color_by_form := true

var _models: Array[Node3D] = []
var _material := StandardMaterial3D.new()


func _ready() -> void:
	var origin := get_parent() as XROrigin3D
	if origin == null:
		push_warning("HandVisuals : doit être enfant d'un XROrigin3D.")
		return

	_material.roughness = 0.8
	_material.albedo_color = SKIN_COLORS["human"]

	for side in ["LeftHand", "RightHand"]:
		var controller := origin.get_node_or_null(side) as XRController3D
		if controller == null:
			push_warning("HandVisuals : nœud '%s' introuvable." % side)
			continue
		_add_model(controller, side == "LeftHand")

	_apply_material()
	if color_by_form and origin.has_signal("form_changed"):
		origin.connect("form_changed", _on_form_changed)


func _add_model(controller: XRController3D, is_left: bool) -> void:
	# Une main existe déjà sur cette manette : on ne la double pas
	if controller.get_node_or_null("HandModel") != null:
		return
	if not controller.find_children("*", "XRToolsHand", true, false).is_empty():
		return

	var model: Node3D = null
	var path := LEFT_HAND_PATH if is_left else RIGHT_HAND_PATH
	if use_xr_tools_hands and ResourceLoader.exists(path):
		var scene := load(path) as PackedScene
		if scene:
			model = scene.instantiate() as Node3D
	if model == null:
		push_warning("HandVisuals : main XR Tools introuvable (%s), manette simplifiée utilisée." % path)
		model = _make_simple_controller()

	model.name = "HandModel"
	controller.add_child(model)
	_models.append(model)


# Manette de remplacement : une poignée et un petit embout vers l'avant
func _make_simple_controller() -> Node3D:
	var root := Node3D.new()

	var grip := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.025
	capsule.height = 0.14
	grip.mesh = capsule
	grip.rotation_degrees = Vector3(90, 0, 0)   # couchée le long de l'axe avant
	root.add_child(grip)

	var tip := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.022
	sphere.height = 0.044
	tip.mesh = sphere
	tip.position = Vector3(0, 0, -0.085)
	root.add_child(tip)

	return root


func _apply_material() -> void:
	for model in _models:
		if "hand_material_override" in model:
			model.set("hand_material_override", _material)
		else:
			for node in model.find_children("*", "MeshInstance3D", true, false):
				(node as MeshInstance3D).material_override = _material


func _on_form_changed(form: String) -> void:
	_material.albedo_color = SKIN_COLORS.get(form, SKIN_COLORS["human"])
