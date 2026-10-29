class_name FormSwitcher
extends Node3D

@export var gorilla_scene: PackedScene
@export var chicken_scene: PackedScene
@export var spider_scene: PackedScene
@export_enum("gorilla", "chicken", "spider") var start_form := "spider"

var current: CharacterBody3D
var current_form := ""

@onready var scenes := {
    "gorilla": gorilla_scene,
    "chicken": chicken_scene,
    "spider": spider_scene,
}

# Hauteurs de compensation selon les formes pour éviter d'entrer dans le sol
const FORM_OFFSETS := {
    "gorilla": 0.5,
    "chicken": 0.2,
    "spider": 0.05
}


func _ready() -> void:
    switch_to(start_form)


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("form_gorilla"):
        switch_to("gorilla")
    elif event.is_action_pressed("form_chicken"):
        switch_to("chicken")
    elif event.is_action_pressed("form_spider"):
        switch_to("spider")


func switch_to(form: String) -> void:
    if form == current_form:
        return
    var packed: PackedScene = scenes.get(form)
    if packed == null:
        push_warning("Aucune scène assignée pour : " + form)
        return

    # On mémorise l'état de l'animal actuel
    var xf := global_transform
    var vel := Vector3.ZERO
    if current:
        xf = current.global_transform
        vel = current.velocity
        
        # Ajustement intelligent de la hauteur en fonction du nouvel animal
        var offset = FORM_OFFSETS.get(form, 0.1)
        xf.origin.y += offset
        
        remove_child(current)
        current.queue_free()

    # On crée le nouveau
    var body := packed.instantiate() as CharacterBody3D
    add_child(body)
    body.global_transform = xf
    body.velocity = vel

    var cam := body.find_child("Camera3D", true, false) as Camera3D
    if cam:
        cam.make_current()

    current = body
    current_form = form