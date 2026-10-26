class_name PlayerXR
extends XROrigin3D

signal form_changed(form: String)

@export_enum("gorilla", "chicken", "spider") var start_form := "spider"

const FORMS := ["gorilla", "chicken", "spider"]

# Réglages par animal : taille (world_scale) et vitesse de saut
const FORM_DATA := {
	"gorilla": {"scale": 1.3, "jump": 10.0},
	"chicken": {"scale": 0.8, "jump": 5.0},
	"spider":  {"scale": 0.5, "jump": 4.5},
}

@onready var left_hand: XRController3D = $LeftHand
@onready var right_hand: XRController3D = $RightHand

@onready var jump: Node = $RightHand/XRToolsMovementJump
@onready var glide: Node = $RightHand/XRToolsMovementGlide
@onready var smash: Node = $RightHand/SmashVR
@onready var web: Node = $RightHand/WebVR
@onready var climb_left: Node = $LeftHand/XRToolsMovementClimb
@onready var climb_right: Node = $RightHand/XRToolsMovementClimb

var current_form := ""


func _ready() -> void:
	left_hand.tracker = &"left_hand"
	right_hand.tracker = &"right_hand"

	left_hand.button_pressed.connect(_on_left_button)
	# Diagnostic : à retirer quand les boutons sont validés
	left_hand.button_pressed.connect(func(b: String) -> void: print("GAUCHE : ", b))
	right_hand.button_pressed.connect(func(b: String) -> void: print("DROITE : ", b))

	switch_to(start_form)


func _on_left_button(button: String) -> void:
	# Bouton Y (manette gauche) : forme suivante
	if button == "by_button":
		var next: int = (FORMS.find(current_form) + 1) % FORMS.size()
		switch_to(FORMS[next])


func switch_to(form: String) -> void:
	if form == current_form or not FORM_DATA.has(form):
		return
	current_form = form

	var data: Dictionary = FORM_DATA[form]
	# world_scale = data["scale"]
	_set_prop(jump, "jump_velocity", data["jump"])

	# On n'active que les capacités de l'animal courant
	_enable(smash, form == "gorilla")
	_enable(glide, form == "chicken")
	_enable(web, form == "spider")
	_enable(climb_left, form == "spider")
	_enable(climb_right, form == "spider")

	form_changed.emit(form)


func _enable(node: Node, value: bool) -> void:
	_set_prop(node, "enabled", value)


func _set_prop(node: Node, prop: String, value: Variant) -> void:
	if node == null:
		return
	node.set(prop, value)