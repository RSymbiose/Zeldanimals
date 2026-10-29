extends Node

const FADE_TIME := 0.35

# Forme de l'animal, conservée d'un niveau à l'autre ("" = valeur par défaut du niveau)
var current_form := ""

var _busy := false


func go_to(path: String) -> void:
	if _busy:
		return
	if not ResourceLoader.exists(path):
		push_warning("SceneManager : scène introuvable : " + path)
		return
	_busy = true

	# Fondu vers le noir, puis changement de scène
	var quad := _attach_fade_quad()
	if quad:
		var tween_out := create_tween()
		tween_out.tween_method(_set_fade.bind(quad), 0.0, 1.0, FADE_TIME)
		await tween_out.finished

	get_tree().change_scene_to_file(path)

	# On attend que le nouveau joueur et sa caméra existent
	for i in 30:
		await get_tree().process_frame
		if i > 2 and get_viewport().get_camera_3d() != null:
			break

	# Fondu depuis le noir sur la nouvelle caméra
	var quad_in := _attach_fade_quad()
	if quad_in:
		_set_fade(1.0, quad_in)
		var tween_in := create_tween()
		tween_in.tween_method(_set_fade.bind(quad_in), 1.0, 0.0, FADE_TIME)
		await tween_in.finished
		if is_instance_valid(quad_in):
			quad_in.queue_free()

	_busy = false


# Le fondu est un quad noir collé devant la caméra : un écran 2D (CanvasLayer)
# n'est pas visible dans un casque VR.
func _attach_fade_quad() -> MeshInstance3D:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(4.0, 4.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0, 0, 0, 0)
	mat.no_depth_test = true
	mat.render_priority = 127
	mesh.material = mat
	quad.mesh = mesh
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.position = Vector3(0, 0, -0.25)      # juste devant les yeux
	cam.add_child(quad)
	return quad


func _set_fade(alpha: float, quad: MeshInstance3D) -> void:
	if not is_instance_valid(quad):
		return
	var mat := (quad.mesh as QuadMesh).material as StandardMaterial3D
	mat.albedo_color = Color(0, 0, 0, alpha)