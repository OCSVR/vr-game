extends Node3D
## Build-plan step 1: the laptop workbench with one snap task.
## Done when the RAM stick snaps into its slot with the mouse.
##
## Kept as the simplest sandbox for the snap mechanics (and their tests).
## The real missions live in scenes/build_computer/.

const SnapZone := preload("res://scripts/snap_zone.gd")
const GrabbablePart := preload("res://scripts/grabbable_part.gd")

@onready var sign_label: Label3D = $Sign
@onready var ram_slot: SnapZone = $Motherboard/RamSlot


func _ready() -> void:
	ram_slot.snapped.connect(_on_snapped)
	ram_slot.rejected.connect(_on_rejected)
	sign_label.text = "Drag the RAM stick into the RAM slot"


func _on_snapped(_zone: SnapZone, part: GrabbablePart) -> void:
	sign_label.text = "%s installed!" % part.display_name


func _on_rejected(zone: SnapZone, part: GrabbablePart) -> void:
	sign_label.text = "A %s doesn't go in the %s. Try again." % [part.display_name, zone.display_name]
