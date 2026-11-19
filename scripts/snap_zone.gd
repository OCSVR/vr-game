extends Area3D
## A place a part goes: a RAM slot, a CPU socket, a switch port.
##
## Mr. Mortensen's plan: one reusable SnapZone handles drop detection, and
## "that's your whole task system". When a part is dropped while it overlaps
## this zone, the zone either installs it (right type) or turns it away (wrong
## type, which counts as a failed attempt). Missions only listen to the signals.

const GrabbablePart := preload("res://scripts/grabbable_part.gd")

## A part of the right type was dropped here and is now installed.
signal snapped(zone, part)
## A part of the wrong type was dropped here; it went back home.
signal rejected(zone, part)

## The part type this zone takes, e.g. &"ram". Matches GrabbablePart.part_type.
@export var accepts: StringName = &"ram"
## What the zone is called in hints, e.g. "RAM slot".
@export var display_name: String = "RAM slot"

var installed_part: GrabbablePart = null

@onready var _snap_point: Node3D = get_node_or_null("SnapPoint")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func is_filled() -> bool:
	return installed_part != null


## Where an installed part's origin goes. A child Marker3D named SnapPoint sets
## it; without one, the zone's own origin is used.
func snap_transform() -> Transform3D:
	return _snap_point.global_transform if _snap_point else global_transform


func _on_body_entered(body: Node) -> void:
	var part := body as GrabbablePart
	if part and not part.dropped.is_connected(_on_part_dropped):
		part.dropped.connect(_on_part_dropped)


func _on_body_exited(body: Node) -> void:
	var part := body as GrabbablePart
	if part and part.dropped.is_connected(_on_part_dropped):
		part.dropped.disconnect(_on_part_dropped)


func _on_part_dropped(part: GrabbablePart) -> void:
	if part.is_installed or is_filled():
		return
	if part.part_type == accepts:
		installed_part = part
		part.install(self, snap_transform())
		snapped.emit(self, part)
	else:
		rejected.emit(self, part)
