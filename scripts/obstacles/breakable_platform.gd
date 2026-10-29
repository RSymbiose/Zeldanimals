class_name BreakablePlatform
extends Node3D

@export var break_delay: float = 0.25 # Délai avant écroulement
@export var respawn_time: float = 0.0 # 0.0 = destruction définitive

@onready var static_body_col: CollisionShape3D = $StaticBody3D/CollisionShape3D
@onready var area_col: CollisionShape3D = $Area3D/TriggerShape3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var particles: GPUParticles3D = $DebrisParticles
@onready var area: Area3D = $Area3D
@onready var break_sound: AudioStreamPlayer3D = get_node_or_null("AudioStreamPlayer3D")

var is_broken: bool = false

func _ready() -> void:
	area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	trigger_break()

func trigger_break() -> void:
	is_broken = true
	static_body_col.set_deferred("disabled", true)
	area_col.set_deferred("disabled", true)
	mesh.visible = false

	# Micro-secousse visuelle avant la chute
	var tween = create_tween()
	tween.tween_property(mesh, "position:y", mesh.position.y - 0.05, break_delay * 0.5)
	tween.tween_property(mesh, "position:y", mesh.position.y, break_delay * 0.5)
	await tween.finished

	# Désactivation propre des collisions
	static_body_col.set_deferred("disabled", true)
	area_col.set_deferred("disabled", true)
	mesh.visible = false

	if break_sound:
		break_sound.play()
		
	if particles:
		particles.restart()

	if respawn_time > 0.0:
		await get_tree().create_timer(respawn_time).timeout
		_respawn()
	else:
		# Nettoyage mémoire après l'extinction des particules
		await get_tree().create_timer(1.5).timeout
		queue_free()

func _respawn() -> void:
	mesh.visible = true
	static_body_col.set_deferred("disabled", false)
	area_col.set_deferred("disabled", false)
	is_broken = false
