class_name SlidingDoor
extends AnimatableBody3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio_player: AudioStreamPlayer3D = $AudioGrincement # Assure-toi que le nom correspond

func open() -> void:
	animation_player.play("ouverture_porte")
	if audio_player and not audio_player.playing:
		audio_player.play() # Lance le grincement à l'ouverture

func close() -> void:
	animation_player.play("fermeture_porte")
	if audio_player and not audio_player.playing:
		audio_player.play() # Lance le grincement à la fermeture

func _on_pressure_plate_pressed() -> void:
	open()

func _on_pressure_plate_released() -> void:
	close()
