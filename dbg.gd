extends Node

var lines: Array[String] = []
var label: Label3D

func _ready() -> void:
	label = Label3D.new()
	label.pixel_size = 0.0008
	label.font_size = 40
	label.no_depth_test = true
	label.render_priority = 127
	label.modulate = Color.YELLOW
	label.position = Vector3(0, 0, -1.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(label)

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and label.get_parent() != cam:
		label.reparent(cam, false)

func say(msg: String) -> void:
	print(msg)
	lines.append(msg)
	if lines.size() > 12:
		lines.pop_front()
	label.text = "\n".join(lines)
