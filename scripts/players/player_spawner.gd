class_name PlayerSpawner
extends Node3D
# Crée le bon joueur (PC ou VR) au point de départ du niveau,
# et le ramène à ce point s'il tombe dans le vide.
# Pose ce nœud à l'endroit où le joueur doit apparaître (et réapparaître).

signal player_died
signal player_respawned

@export var pc_player: PackedScene   # form_switcher.tscn
@export var xr_player: PackedScene   # player_xr.tscn

@export_group("Chute dans le vide")
@export var void_death_enabled := true
@export var kill_y := -15.0          # hauteur MONDE sous laquelle le joueur "meurt"

var _player: Node3D
var _respawning := false
var _fade_rect: ColorRect


func _ready() -> void:
	add_to_group("player_spawner") # Permet de retrouver le spawner depuis les piques
	
	var scene := xr_player if PlatformManager.is_vr else pc_player
	print("PlayerSpawner: VR=%s, scène=%s" % [PlatformManager.is_vr, scene])
	if scene == null:
		push_error("PlayerSpawner: scène joueur non assignée (champ vide dans l'inspecteur) -> aucune caméra")
		return

	var player := scene.instantiate() as Node3D
	get_parent().add_child.call_deferred(player)
	await player.ready
	player.global_transform = global_transform
	_player = player
	print("PlayerSpawner: joueur créé en ", global_position)

func force_respawn() -> void:
	if _respawning:
		return
	_die_and_respawn()

func _physics_process(_delta: float) -> void:
	if not void_death_enabled or _player == null or _respawning:
		return
	# La caméra active est toujours à la tête du joueur : ça marche pour
	# n'importe quel animal sur PC et pour le casque en VR.
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.y < kill_y:
		_die_and_respawn()


func _die_and_respawn() -> void:
	_respawning = true
	print("PlayerSpawner: chute dans le vide -> retour au départ")
	player_died.emit()

	# Fondu au noir rapide sur PC (un écran 2D n'est pas visible dans un casque)
	if not PlatformManager.is_vr:
		await _fade(1.0, 0.15)
	_teleport_player()
	if not PlatformManager.is_vr:
		await _fade(0.0, 0.3)

	_respawning = false
	player_respawned.emit()


func _teleport_player() -> void:
	var spawn := Transform3D(global_transform.basis.orthonormalized(), global_position)

	# VR : on passe par le PlayerBody de XR Tools, qui déplace tout le rig
	if _player is XROrigin3D:
		var body := _player.get_node_or_null("PlayerBody")
		if body and body.has_method("teleport"):
			body.teleport(spawn)
		else:
			_player.global_transform = spawn
		return

	# PC : le corps actif (gorille, poule ou araignée)
	var bodies: Array[Node] = []
	if _player is CharacterBody3D:
		bodies.append(_player)
	bodies.append_array(_player.find_children("*", "CharacterBody3D", true, false))
	for node in bodies:
		var character := node as CharacterBody3D
		character.global_transform = spawn
		character.velocity = Vector3.ZERO


func _fade(target_alpha: float, duration: float) -> void:
	if _fade_rect == null:
		var layer := CanvasLayer.new()
		layer.layer = 99
		_fade_rect = ColorRect.new()
		_fade_rect.color = Color(0, 0, 0, 0)
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.add_child(_fade_rect)
		add_child(layer)
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", target_alpha, duration)
	await tween.finished
