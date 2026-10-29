class_name LevelIntro
extends Node
# Affiche un message au début du niveau (ex. "Bienvenue dans le niveau 2").
#  - PC : texte centré à l'écran (CanvasLayer)
#  - VR : texte flottant devant le joueur (un écran 2D n'est pas visible dans un casque)
# À poser comme simple Node dans chaque niveau.

@export_multiline var text := "Bienvenue dans le niveau 2"
@export var delay := 0.8           # attente avant l'affichage (fondu du SceneManager + création du joueur)
@export var duration := 3.0        # durée d'affichage à pleine opacité (s)
@export var fade_time := 0.6       # durée de l'apparition et de la disparition (s)
@export var font_size := 64


func _ready() -> void:
	await get_tree().create_timer(delay).timeout
	# Le joueur est créé par le PlayerSpawner : on attend que sa caméra existe
	for i in 60:
		if get_viewport().get_camera_3d() != null:
			break
		await get_tree().process_frame
	if _is_vr():
		_show_3d()
	else:
		_show_2d()


func _show_2d() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 99
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 12)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.modulate.a = 0.0
	layer.add_child(label)
	get_tree().current_scene.add_child(layer)

	var tween := layer.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, fade_time)
	tween.tween_interval(duration)
	tween.tween_property(label, "modulate:a", 0.0, fade_time)
	tween.tween_callback(layer.queue_free)


func _show_3d() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return

	# Texte placé à 2,5 m devant le joueur, puis fixe dans le monde
	# (un message collé au visage donne mal au coeur en VR).
	var forward := -cam.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	var pos := cam.global_position + forward * 2.5

	var panel := Node3D.new()
	get_tree().current_scene.add_child(panel)
	panel.look_at_from_position(pos, cam.global_position, Vector3.UP, true)

	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.004
	label.outline_size = 12
	label.no_depth_test = true
	label.render_priority = 2
	label.outline_render_priority = 1
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate.a = 0.0
	label.outline_modulate.a = 0.0
	panel.add_child(label)

	var tween := panel.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, fade_time)
	tween.tween_property(label, "outline_modulate:a", 1.0, fade_time)
	tween.chain().tween_interval(duration)
	tween.chain().tween_property(label, "modulate:a", 0.0, fade_time)
	tween.parallel().tween_property(label, "outline_modulate:a", 0.0, fade_time)
	tween.chain().tween_callback(panel.queue_free)


func _is_vr() -> bool:
	var manager := get_node_or_null("/root/PlatformManager")
	return manager != null and manager.is_vr