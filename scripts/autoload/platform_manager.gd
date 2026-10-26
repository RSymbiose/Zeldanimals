extends Node

const SIMULATE_VR := true   # false pour jouer en PC normal ou avec un vrai casque

var is_vr := false

func _ready() -> void:
	var xr := XRServer.find_interface("OpenXR")
	if xr and xr.is_initialized():
		is_vr = true
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	elif SIMULATE_VR:
		is_vr = true