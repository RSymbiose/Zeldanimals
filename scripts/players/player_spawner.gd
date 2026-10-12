class_name PlayerSpawner
extends Node3D

@export var pc_player: PackedScene   # form_switcher.tscn
@export var xr_player: PackedScene   # player_xr.tscn


func _ready() -> void:
	var scene := xr_player if PlatformManager.is_vr else pc_player
	var player := scene.instantiate() as Node3D
	get_parent().add_child.call_deferred(player)
	await player.ready
	player.global_transform = global_transform