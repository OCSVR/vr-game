extends RigidBody3D
## A part the player can pick up and drop: a RAM stick, a CPU, a network cable...
##
## VR rule 7: this node holds the logic and a simple collision shape, and the
## visual mesh is a child, so swapping in a real model only replaces that child.
## VR rule 8: the node's origin is the snap point (e.g. the bottom edge of a RAM
## stick), so a SnapZone can place it by matching transforms.
##
## The part never knows what is moving it. A grabber (mouse now, controllers or
## hands later) calls grab(), moves the part, then calls drop(). SnapZones listen
## for `dropped` and decide whether the part belongs to them.

## Emitted by drop(). SnapZones under the part connect to it.
signal dropped(part)
## Emitted when a SnapZone accepts the part.
signal installed(part, zone)

## What kind of part this is. A SnapZone accepts parts whose type matches its own.
@export var part_type: StringName = &"ram"
## The name shown to students in hints and on the success panel.
@export var display_name: String = "RAM stick"

var is_held := false
var is_installed := false
## Where the part goes back to when it's dropped somewhere that isn't its slot.
var home_transform: Transform3D


func _ready() -> void:
	# Kinematic: parts never fall or tumble. Dropping one outside a slot sends it
	# home instead, so nothing ends up on the floor out of reach (VR rule 2).
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	home_transform = global_transform


func can_grab() -> bool:
	return not is_installed and not is_held


func grab() -> bool:
	if not can_grab():
		return false
	is_held = true
	return true


## Lets go of the part. SnapZones it is over get the chance to take it;
## if none does, it goes back home.
func drop() -> void:
	if not is_held:
		return
	is_held = false
	dropped.emit(self)
	if not is_installed:
		return_home()


func return_home() -> void:
	global_transform = home_transform


## Called by the SnapZone that accepted the part.
func install(zone: Node3D, at: Transform3D) -> void:
	global_transform = at
	is_installed = true
	installed.emit(self, zone)
