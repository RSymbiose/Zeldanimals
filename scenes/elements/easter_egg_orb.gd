class_name EasterEggOrb
extends Area3D

@export var easter_egg_music: AudioStream
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var _triggered := false


func _ready() -> void:
	# Le PlayerBody VR (XR Tools) est sur la couche 20, pas sur la couche 1 :
	# on détecte toutes les couches, puis on filtre par type de corps ci-dessous.
	collision_mask = 0xFFFFF
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _triggered:
		return

	if body.is_in_group("player") or body is CharacterBody3D:
		_triggered = true

		if easter_egg_music and audio_player:
			audio_player.stream = easter_egg_music
			audio_player.play()
			print("Easter Egg activé : Musique de Johnny lancée !")

		# 1. Désactive la collision pour ne plus déclencher le code
		$CollisionShape3D.set_deferred("disabled", true)

		# 2. Rend l'image de Johnny invisible
		if mesh_instance:
			mesh_instance.visible = false
