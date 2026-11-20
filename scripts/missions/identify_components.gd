extends Node3D
## Build-plan step 2: Module 1, Mission 1, "Identify components".
## AP CSP Unit 4: a computer needs a processor, memory, storage and a way to
## talk to people (input/output). The student puts each part where it belongs.
##
## States go Intro -> Active -> Success, as in Mr. Mortensen's plan. The timer
## starts when the student first picks up a part. Every part dropped on the
## wrong slot is a mistake: the panel explains what that slot is for, and the
## score drops. Step 4 moves this flow into the TrainingManager autoload and the
## part list into the module registry; step 5 sends `mission_completed` to Flask.

const SnapZone := preload("res://scripts/snap_zone.gd")
const GrabbablePart := preload("res://scripts/grabbable_part.gd")
const InfoPanel := preload("res://scripts/ui/info_panel.gd")

## The id the training API stores, "module.mission".
const MODULE_ID := "build_computer.identify_components"
## Score starts here and loses MISTAKE_PENALTY per wrong drop, never below 0.
const FULL_SCORE := 100
const MISTAKE_PENALTY := 10

enum State { INTRO, ACTIVE, SUCCESS }

## Emitted once, when every slot is filled. `attempts` is 1 plus the number of
## wrong drops (the tries the student needed), matching the API's field.
signal mission_completed(module_id: String, score: int, duration_s: int, attempts: int)

var state := State.INTRO
var mistakes := 0
var score := FULL_SCORE
var duration_s := 0
var _started_ms := 0
## Overridable clock, so tests can control time.
var now_ms: Callable = Time.get_ticks_msec

@onready var panel: InfoPanel = $InfoPanel
@onready var zones: Array[SnapZone] = _find_zones()


func _ready() -> void:
	$Room.grabber.part_grabbed.connect(_on_part_grabbed)
	for zone in zones:
		zone.snapped.connect(_on_snapped)
		zone.rejected.connect(_on_rejected)
	panel.show_text("Identify the components", PackedStringArray([
		"Every computer needs four things: a processor, memory, storage, and a way to talk to people.",
		"Put each part on the table where it belongs. Pick up any part to start.",
	]))


func _find_zones() -> Array[SnapZone]:
	var found: Array[SnapZone] = []
	for node in find_children("*", "Area3D", true, false):
		if node is SnapZone:
			found.append(node)
	return found


func _on_part_grabbed(_part: GrabbablePart) -> void:
	if state == State.INTRO:
		state = State.ACTIVE
		_started_ms = now_ms.call()
		_show_checklist("")


func _on_snapped(zone: SnapZone, part: GrabbablePart) -> void:
	if state != State.ACTIVE:
		return
	if zones.all(func(z: SnapZone) -> bool: return z.is_filled()):
		_finish()
	else:
		_show_checklist("Yes! The %s goes in the %s." % [part.display_name, zone.display_name])


func _on_rejected(zone: SnapZone, part: GrabbablePart) -> void:
	if state != State.ACTIVE:
		return
	mistakes += 1
	score = maxi(0, FULL_SCORE - MISTAKE_PENALTY * mistakes)
	var why := zone.hint if zone.hint != "" else "Something else goes in the %s." % zone.display_name
	_show_checklist("The %s doesn't go there. %s" % [part.display_name, why])


func _finish() -> void:
	state = State.SUCCESS
	duration_s = roundi((now_ms.call() - _started_ms) / 1000.0)
	panel.show_text("Mission complete!", PackedStringArray([
		"You built the core of a computer: processor, memory, storage and input.",
		"Score: %d   Time: %s   Mistakes: %d" % [score, _clock(duration_s), mistakes],
	]))
	mission_completed.emit(MODULE_ID, score, duration_s, mistakes + 1)


## The checklist: one line per slot, ticked once its part is in, plus feedback.
func _show_checklist(feedback: String) -> void:
	var out := PackedStringArray()
	for zone in zones:
		out.append(("[x] " if zone.is_filled() else "[  ] ") + zone.display_name)
	if feedback != "":
		out.append("")
		out.append(feedback)
	panel.show_text("Identify the components", out)


static func _clock(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]
