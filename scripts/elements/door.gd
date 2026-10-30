class_name SlidingDoor
extends AnimatableBody3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio_player: AudioStreamPlayer3D = $AudioGrincement

func open() -> void:
	animation_player.play("ouverture_porte")
	if audio_player and not audio_player.playing:
		audio_player.play()

func close() -> void:
	animation_player.play("fermeture_porte")
	if audio_player and not audio_player.playing:
		audio_player.play()

func _on_pressure_plate_pressed() -> void:
	open()

func _on_pressure_plate_released() -> void:
	close()
