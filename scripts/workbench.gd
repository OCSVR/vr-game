extends Node3D
## Build-plan step 1: the laptop workbench with one snap task.
## Done when the RAM stick snaps into its slot with the mouse.
##
## The instruction sign is a Label3D, not screen UI, because CanvasLayer UI
## doesn't show up in the headset (VR rule 4). Step 2 moves this text onto a
## proper 3D panel with hints and a success screen.

const SnapZone := preload("res://scripts/snap_zone.gd")
const GrabbablePart := preload("res://scripts/grabbable_part.gd")
const MouseGrabber := preload("res://scripts/input/mouse_grabber.gd")

## Standing eye height for the laptop camera (meters). VR rule 2; replace with
## the comfortable height measured in step 0.
const EYE_HEIGHT := 1.6

@onready var camera: Camera3D = $Camera3D
@onready var sign_label: Label3D = $Sign
@onready var ram_slot: SnapZone = $Motherboard/RamSlot
@onready var grabber: MouseGrabber = $MouseGrabber


func _ready() -> void:
	# Placed and aimed once at the motherboard, then never moved by the game (VR rule 6).
	camera.position.y = EYE_HEIGHT
	camera.look_at($Motherboard.global_position + Vector3(0, 0, 0.05))
	grabber.camera = camera
	ram_slot.snapped.connect(_on_snapped)
	ram_slot.rejected.connect(_on_rejected)
	sign_label.text = "Drag the RAM stick into the RAM slot"


func _on_snapped(_zone: SnapZone, part: GrabbablePart) -> void:
	sign_label.text = "%s installed!" % part.display_name


func _on_rejected(zone: SnapZone, part: GrabbablePart) -> void:
	sign_label.text = "A %s doesn't go in the %s. Try again." % [part.display_name, zone.display_name]
