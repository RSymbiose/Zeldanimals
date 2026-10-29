class_name KeyPickup
extends Area3D
# Clé de fin de niveau : quand le joueur la touche, elle disparaît
# et un écran de fin s'affiche avec le temps mis pour finir le niveau.
#  - PC  : écran sombre plein cadre avec le message (CanvasLayer)
#  - VR  : panneau flottant devant le joueur (un écran 2D n'est pas visible dans un casque)
#
# Structure de la scène :
#   KeyPickup (Area3D, ce script)
#    ├─ CollisionShape3D   (SphereShape3D, rayon ~0,7)
#    └─ Model              (le modèle 3D de la clé)

signal collected

@export_multiline var message := "Bien joué !\nVous avez terminé le niveau\nen {temps}"
@export var loading_text := "Chargement du niveau suivant..."   # affiché seulement si next_scene est renseigné
@export var reload_after := 0.0      # secondes avant de relancer le niveau (0 = jamais)
@export var spin_speed := 1.5        # rotation de la clé (rad/s)
@export var bob_height := 0.1        # amplitude du va-et-vient vertical (m)

@onready var model: Node3D = $Model
@onready var shape: CollisionShape3D = $CollisionShape3D
@export_file("*.tscn") var next_scene: String        # niveau à charger après la clé
@export var next_scene_delay := 4.0                  # secondes avant la téléportation (laisse lire le chrono)

var elapsed_time := 0.0              # temps final en secondes (lisible par d'autres scripts)

var _collected := false
var _time := 0.0
var _model_rest_y := 0.0
var _start_ms := 0


func _ready() -> void:
	# Le chrono démarre au chargement du niveau
	_start_ms = Time.get_ticks_msec()

	# On détecte toutes les couches (le PlayerBody VR n'est pas forcément sur la couche 1)
	# et on filtre par type de corps dans _on_body_entered.
	collision_mask = 0xFFFFF
	body_entered.connect(_on_body_entered)
	_model_rest_y = model.position.y


func _process(delta: float) -> void:
	if _collected:
		return
	_time += delta
	model.rotate_y(spin_speed * delta)
	model.position.y = _model_rest_y + sin(_time * 2.0) * bob_height


func _on_body_entered(body: Node3D) -> void:
	if _collected or not (body is CharacterBody3D):
		return
	_collected = true
	elapsed_time = (Time.get_ticks_msec() - _start_ms) / 1000.0
	collected.emit()
	shape.set_deferred("disabled", true)

	# La clé rétrécit en montant, puis disparaît
	var tween := create_tween().set_parallel(true)
	tween.tween_property(model, "scale", Vector3.ZERO, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(model, "position:y", model.position.y + 0.5, 0.3)
	tween.chain().tween_callback(queue_free)

	_show_end_screen(_build_end_text())

	if next_scene != "":
		get_tree().create_timer(next_scene_delay).timeout.connect(
			SceneManager.go_to.bind(next_scene))
	elif reload_after > 0.0:
		get_tree().create_timer(reload_after).timeout.connect(get_tree().reload_current_scene)


# Message + chrono, par exemple "Vous avez fini le niveau, bravo !" puis "Temps : 01:23.45"
func _build_end_text() -> String:
	var text := message.replace("{temps}", _format_time(elapsed_time))
	if next_scene != "":
		text += "\n\n" + loading_text
	return text


func _format_time(seconds: float) -> String:
	var minutes := int(seconds / 60.0)
	var secs := fmod(seconds, 60.0)
	return "%02d:%05.2f" % [minutes, secs]


func _show_end_screen(text: String) -> void:
	var manager := get_node_or_null("/root/PlatformManager")
	var in_vr: bool = manager != null and manager.is_vr
	if in_vr:
		_show_screen_3d(text)
	else:
		_show_screen_2d(text)


func _show_screen_2d(text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100

	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.7)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(background)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 56)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_child(label)

	get_tree().current_scene.add_child(layer)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # libère la souris (le gorille la capture)


func _show_screen_3d(text: String) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return

	# Panneau placé à 2,5 m devant le joueur, à hauteur des yeux, puis fixe dans le monde
	# (un message collé au visage donne mal au coeur en VR).
	var forward := -cam.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	var pos := cam.global_position + forward * 2.5

	var panel := Node3D.new()
	get_tree().current_scene.add_child(panel)
	panel.look_at_from_position(pos, cam.global_position, Vector3.UP, true)

	var quad := MeshInstance3D.new()
	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(2.8, 1.6)    # plus haut : le texte fait maintenant 4 lignes
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0, 0, 0, 0.75)
	material.no_depth_test = true
	quad_mesh.material = material
	quad.mesh = quad_mesh
	panel.add_child(quad)

	var label := Label3D.new()
	label.text = text
	label.font_size = 56
	label.pixel_size = 0.003
	label.outline_size = 8
	label.no_depth_test = true
	label.render_priority = 2
	label.outline_render_priority = 1
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector3(0, 0, 0.01)
	panel.add_child(label)
