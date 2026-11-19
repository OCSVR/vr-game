extends Node3D
## The room every mission happens in: light, floor, the work table, the
## standing camera and the laptop's grab layer. Missions instance this scene
## and put their own parts and slots on the table.

const MouseGrabber := preload("res://scripts/input/mouse_grabber.gd")

## Standing eye height for the laptop camera (meters). VR rule 2; replace with
## the comfortable height measured in step 0.
const EYE_HEIGHT := 1.6
## Height of the table top (meters). The table mesh is 0.05 m thick at 0.875.
const TABLE_TOP := 0.9

## Where the camera looks: the middle of the work area on the table.
@export var focus := Vector3(0, TABLE_TOP, -0.1)

@onready var camera: Camera3D = $Camera3D
@onready var grabber: MouseGrabber = $MouseGrabber


func _ready() -> void:
	# Placed and aimed once, then never moved by the game (VR rule 6).
	camera.position.y = EYE_HEIGHT
	camera.look_at(focus)
	grabber.camera = camera
