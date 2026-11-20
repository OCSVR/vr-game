extends Node3D
## The one script every mission scene uses. The scene says *where* things are;
## data/modules.json says *what* they are, what the student reads and how the
## mission is scored. So a new mission is a new scene plus a registry entry,
## with no new code (build-plan step 4).
##
## On load it asks the TrainingManager autoload for its mission, gives each
## part and slot its type, name and hint from the registry, and then turns
## grabs, installs and wrong drops into TrainingManager calls and panel text.

const SnapZone := preload("res://scripts/snap_zone.gd")
const GrabbablePart := preload("res://scripts/grabbable_part.gd")
const InfoPanel := preload("res://scripts/ui/info_panel.gd")

## Full mission id in the registry, e.g. "build_computer.identify_components".
@export var mission_id: String = ""

var config: Dictionary = {}
var zones: Array[SnapZone] = []
var parts: Array[GrabbablePart] = []
## Where the mission's problems go (also printed as errors), for tests.
var problems: PackedStringArray = []
## The success panel's lines and the score-saving status under them. Either
## can arrive first: a fast server can answer before the panel is drawn.
var _result_lines := PackedStringArray()
var _save_message := ""

@onready var panel: InfoPanel = $InfoPanel
@onready var manager: Node = get_node("/root/TrainingManager")


func _ready() -> void:
	config = manager.begin(mission_id)
	if config.is_empty():
		_problem("no mission %s in data/modules.json" % mission_id)
		panel.show_text("Mission not found", PackedStringArray([mission_id]))
		return
	_apply_registry()
	$Room.grabber.part_grabbed.connect(_on_part_grabbed)
	for zone in zones:
		zone.snapped.connect(_on_snapped)
		zone.rejected.connect(_on_rejected)
	manager.module_completed.connect(_on_module_completed)
	var reporter := get_node_or_null("/root/ScoreReporter")
	if reporter:
		reporter.report_finished.connect(_on_report_finished)
	panel.show_text(config.title, PackedStringArray(config.intro))


## Gives the scene's parts and slots their registry data. The registry is the
## one place types, names and hints live; the scene only places the nodes.
func _apply_registry() -> void:
	for path in config.parts:
		var part := get_node_or_null(path) as GrabbablePart
		if part == null:
			_problem('part "%s" isn\'t a GrabbablePart in %s' % [path, scene_file_path])
			continue
		part.part_type = StringName(config.parts[path].type)
		part.display_name = config.parts[path].name
		var tag := part.get_node_or_null("Name") as Label3D
		if tag:
			tag.text = part.display_name.capitalize() if part.display_name == part.display_name.to_lower() else part.display_name
		parts.append(part)
	for path in config.slots:
		var zone := get_node_or_null(path) as SnapZone
		if zone == null:
			_problem('slot "%s" isn\'t a SnapZone in %s' % [path, scene_file_path])
			continue
		var slot: Dictionary = config.slots[path]
		zone.accepts = StringName(slot.accepts)
		zone.display_name = slot.name
		zone.hint = slot.hint
		zones.append(zone)
	# Anything in the scene the registry doesn't list would never be scored.
	for node in find_children("*", "Node3D", true, false):
		if (node is SnapZone and not zones.has(node)) or (node is GrabbablePart and not parts.has(node)):
			_problem('"%s" is in the scene but not in the registry' % get_path_to(node))


func _on_part_grabbed(_part: GrabbablePart) -> void:
	var was_intro: bool = manager.state == manager.State.INTRO
	manager.note_grab()
	if was_intro:
		_show_checklist("")


func _on_snapped(zone: SnapZone, part: GrabbablePart) -> void:
	if manager.state != manager.State.ACTIVE:
		return
	if zones.all(func(z: SnapZone) -> bool: return z.is_filled()):
		manager.complete()
	else:
		_show_checklist("Yes! The %s goes in the %s." % [part.display_name, zone.display_name])


func _on_rejected(zone: SnapZone, part: GrabbablePart) -> void:
	if manager.state != manager.State.ACTIVE:
		return
	manager.note_mistake()
	_show_checklist("The %s doesn't go there. %s" % [part.display_name, zone.hint])


func _on_module_completed(_module_id: String, score: int, duration_s: int) -> void:
	_result_lines = PackedStringArray(config.success)
	_result_lines.append("Score: %d   Time: %s   Mistakes: %d" % [score, _clock(duration_s), manager.mistakes])
	_show_result()


func _on_report_finished(_ok: bool, message: String) -> void:
	_save_message = message
	if not _result_lines.is_empty() and is_inside_tree():
		_show_result()


func _show_result() -> void:
	var out := _result_lines.duplicate()
	if not config.practice:
		out.append(_save_message if _save_message != "" else "Saving your score...")
	panel.show_text("Mission complete!", out)


## One line per slot, ticked once its part is in, then any feedback.
func _show_checklist(feedback: String) -> void:
	var out := PackedStringArray()
	for zone in zones:
		out.append(("[x] " if zone.is_filled() else "[  ] ") + zone.display_name)
	if feedback != "":
		out.append("")
		out.append(feedback)
	panel.show_text(config.title, out)


func _problem(text: String) -> void:
	problems.append(text)
	push_error("Mission %s: %s" % [mission_id, text])


static func _clock(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]
