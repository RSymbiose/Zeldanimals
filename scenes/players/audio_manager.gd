# ChickenAudio.gd
class_name ChickenAudio
extends Node

@export var min_idle_delay: float = 5.0
@export var max_idle_delay: float = 14.0

@onready var jump_glide_player: AudioStreamPlayer = $JumpGlidePlayer
@onready var lay_egg_player: AudioStreamPlayer = $LayEggPlayer
@onready var idle_player: AudioStreamPlayer = $IdlePlayer
@onready var idle_timer: Timer = $IdleTimer

func _ready() -> void:
	idle_timer.timeout.connect(_on_idle_timer_timeout)
	_arm_next_idle_sound()

# --- SON 1 : BOUCLE DE SAUT / PLANAGE ---
func update_airborne_sound(is_in_air: bool) -> void:
	if is_in_air:
		if not jump_glide_player.playing:
			jump_glide_player.play()
	else:
		if jump_glide_player.playing:
			jump_glide_player.stop()

# --- SON 2 : PONTE UNIQUE ---
func play_lay_egg_sound() -> void:
	# Modulation légère du pitch (0.95 à 1.05) pour humaniser le son
	lay_egg_player.pitch_scale = randf_range(0.95, 1.05)
	lay_egg_player.play()

# --- SON 3 : GLOUSSEMENT ALÉATOIRE ---
func _arm_next_idle_sound() -> void:
	var next_delay = randf_range(min_idle_delay, max_idle_delay)
	idle_timer.start(next_delay)

func _on_idle_timer_timeout() -> void:
	idle_player.pitch_scale = randf_range(0.9, 1.1)
	idle_player.play()
	_arm_next_idle_sound()
