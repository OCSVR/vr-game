extends SceneTree
## Headless checks for the step 1 workbench. Run from the project folder:
##
##   godot --headless --import          (once, after cloning or adding files)
##   godot --headless --script res://tests/run_tests.gd
##
## Exit code 0 means every check passed. Each test loads a fresh workbench,
## moves parts the way a grabber would, and steps physics so the SnapZone's
## Area3D sees the overlap, exactly as in the game.

const Workbench := preload("res://scenes/workbench.tscn")
const IdentifyComponents := preload("res://scenes/build_computer/identify_components.tscn")
const GrabbablePart := preload("res://scripts/grabbable_part.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_right_part_snaps()
	await _test_drop_outside_goes_home()
	await _test_wrong_part_is_rejected()
	await _test_installed_part_cannot_be_grabbed()
	await _test_mouse_grabber_end_to_end()
	await _test_mission_intro()
	await _test_mission_perfect_run()
	await _test_mission_mistake_gives_hint_and_costs_points()
	await _test_mission_part_homes_are_clear_of_slots()
	print("\n%s" % ("ALL PASSED" if _failures.is_empty() else "%d FAILED" % _failures.size()))
	quit(0 if _failures.is_empty() else 1)


func check(label: String, ok: bool, detail := "") -> void:
	print(("PASS  " if ok else "FAIL  ") + label + ("" if ok or detail == "" else "   [%s]" % detail))
	if not ok:
		_failures.append(label)


func _fresh_bench(scene: PackedScene = Workbench) -> Node3D:
	for child in root.get_children():
		child.queue_free()
	await process_frame
	var bench := scene.instantiate()
	root.add_child(bench)
	await _settle()
	return bench


func _settle(frames := 3) -> void:
	for i in frames:
		await physics_frame


## What a grabber does: pick up, carry to `to`, let physics see it, drop.
func _carry_and_drop(part: GrabbablePart, to: Vector3) -> void:
	part.grab()
	part.global_position = to
	await _settle()
	part.drop()
	await _settle()


func _above_slot(bench: Node3D) -> Vector3:
	var slot: Node3D = bench.get_node("Motherboard/RamSlot")
	return slot.global_position + Vector3(0.01, 0.05, 0.0)


func _test_right_part_snaps() -> void:
	var bench := await _fresh_bench()
	var ram: GrabbablePart = bench.get_node("RamStick")
	var slot = bench.get_node("Motherboard/RamSlot")
	var events := []
	slot.snapped.connect(func(zone, part): events.append([zone, part]))
	await _carry_and_drop(ram, _above_slot(bench))
	check("RAM dropped over the RAM slot snaps in", ram.is_installed and events.size() == 1)
	check("the slot reports the RAM as installed", slot.installed_part == ram)
	var snap: Transform3D = slot.get_node("SnapPoint").global_transform
	check("the RAM sits exactly on the slot's snap point",
		ram.global_transform.origin.distance_to(snap.origin) < 0.0001,
		str(ram.global_transform.origin, " vs ", snap.origin))
	check("the sign says it's installed", bench.get_node("Sign").text == "RAM stick installed!", bench.get_node("Sign").text)


func _test_drop_outside_goes_home() -> void:
	var bench := await _fresh_bench()
	var ram: GrabbablePart = bench.get_node("RamStick")
	var home := ram.global_transform
	await _carry_and_drop(ram, Vector3(0.4, 0.95, 0.2))
	check("RAM dropped away from the slot is not installed", not ram.is_installed)
	check("and goes back where it was picked up", ram.global_transform.is_equal_approx(home))


func _test_wrong_part_is_rejected() -> void:
	var bench := await _fresh_bench()
	var cpu: GrabbablePart = GrabbablePart.new()
	cpu.part_type = &"cpu"
	cpu.display_name = "CPU"
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(0.04, 0.005, 0.04)
	cpu.add_child(shape)
	cpu.position = Vector3(0.3, 0.9, 0.15)
	bench.add_child(cpu)
	await _settle()
	var slot = bench.get_node("Motherboard/RamSlot")
	var rejected := []
	slot.rejected.connect(func(zone, part): rejected.append(part))
	var home := cpu.global_transform
	await _carry_and_drop(cpu, _above_slot(bench))
	check("a CPU dropped on the RAM slot is rejected", rejected == [cpu] and not cpu.is_installed)
	check("and goes back home", cpu.global_transform.is_equal_approx(home))
	check("the slot stays empty", slot.installed_part == null)
	check("the sign explains the mistake", "doesn't go in the RAM slot" in bench.get_node("Sign").text, bench.get_node("Sign").text)


func _test_installed_part_cannot_be_grabbed() -> void:
	var bench := await _fresh_bench()
	var ram: GrabbablePart = bench.get_node("RamStick")
	await _carry_and_drop(ram, _above_slot(bench))
	check("an installed part can't be picked up again", not ram.grab() and not ram.is_held)


## The real input path: the mouse grabber turns screen positions into a grab,
## a carry and a drop, through the camera the player sees.
func _test_mouse_grabber_end_to_end() -> void:
	var bench := await _fresh_bench()
	var ram: GrabbablePart = bench.get_node("RamStick")
	var grabber = bench.get_node("Room/MouseGrabber")
	var camera: Camera3D = bench.get_node("Room/Camera3D")
	var on_ram := camera.unproject_position(ram.global_position + Vector3(0, 0.0155, 0))
	var grabbed = grabber.try_grab_at(on_ram)
	check("pressing on the RAM through the camera picks it up", grabbed == ram and ram.is_held,
		"screen %s" % on_ram)
	var target := _above_slot(bench)
	target.y = grabber.carry_height
	grabber.carry_to(camera.unproject_position(target))
	await _settle()
	check("moving the mouse carries the RAM over the slot at carry height",
		ram.global_position.distance_to(target) < 0.005, str(ram.global_position, " vs ", target))
	grabber.release()
	await _settle()
	check("releasing the mouse drops it into the slot", ram.is_installed and grabber.held == null)
	check("pressing on empty table picks up nothing",
		grabber.try_grab_at(camera.unproject_position(Vector3(0.45, 0.9, 0.25))) == null)


# ---- Step 2: the "Identify components" mission ----

## A fake clock: each call returns the next number from `times` (ms).
func _clock(times: Array) -> Callable:
	return func() -> int: return times.pop_front()


func _slot_top(mission: Node3D, slot_path: String) -> Vector3:
	return (mission.get_node(slot_path) as Node3D).global_position + Vector3(0, 0.05, 0)


## Picks a part up through the real grabber (so the mission sees the grab),
## carries it to `to` and drops it.
func _place(mission: Node3D, part_name: String, to: Vector3) -> void:
	var part: GrabbablePart = mission.get_node(part_name)
	var grabber = mission.get_node("Room/MouseGrabber")
	var camera: Camera3D = mission.get_node("Room/Camera3D")
	var grabbed = grabber.try_grab_at(camera.unproject_position(part.global_position + Vector3(0, 0.005, 0)))
	if grabbed != part:
		check("grabbing the %s through the camera" % part_name, false, "got %s" % grabbed)
		return
	part.global_position = to
	await _settle()
	grabber.release()
	await _settle()


func _test_mission_intro() -> void:
	var mission := await _fresh_bench(IdentifyComponents)
	check("the mission starts in Intro", mission.state == mission.State.INTRO)
	check("it has four slots", mission.zones.size() == 4, str(mission.zones.size()))
	check("the intro panel explains the task", "four things" in mission.panel.text(), mission.panel.text())


func _test_mission_perfect_run() -> void:
	var mission := await _fresh_bench(IdentifyComponents)
	mission.now_ms = _clock([1000, 96000])
	var results := []
	mission.mission_completed.connect(func(id, score, secs, attempts): results.append([id, score, secs, attempts]))
	await _place(mission, "Cpu", _slot_top(mission, "Motherboard/CpuSocket"))
	check("first grab starts the mission", mission.state == mission.State.ACTIVE)
	check("the checklist ticks the CPU socket", "[x] CPU socket" in mission.panel.text(), mission.panel.text())
	await _place(mission, "Ram", _slot_top(mission, "Motherboard/RamSlot"))
	await _place(mission, "Ssd", _slot_top(mission, "Motherboard/M2Slot"))
	check("three of four placed is not finished yet", mission.state == mission.State.ACTIVE)
	await _place(mission, "Keyboard", _slot_top(mission, "UsbPad"))
	check("all four placed: Success", mission.state == mission.State.SUCCESS)
	check("mission_completed fires once with the API's fields",
		results == [["build_computer.identify_components", 100, 95, 1]], str(results))
	check("the success panel shows score and time", "Score: 100" in mission.panel.text() and "1:35" in mission.panel.text(), mission.panel.text())


func _test_mission_mistake_gives_hint_and_costs_points() -> void:
	var mission := await _fresh_bench(IdentifyComponents)
	mission.now_ms = _clock([0, 60000])
	var results := []
	mission.mission_completed.connect(func(id, score, secs, attempts): results.append([score, secs, attempts]))
	await _place(mission, "Ssd", _slot_top(mission, "Motherboard/RamSlot"))
	check("the SSD on the RAM slot is a mistake", mission.mistakes == 1 and not mission.get_node("Ssd").is_installed)
	check("the panel says why, with the RAM slot's hint", "holds what the CPU is working on" in mission.panel.text(), mission.panel.text())
	await _place(mission, "Keyboard", _slot_top(mission, "Motherboard/CpuSocket"))
	check("the keyboard covers three slots but counts as one mistake", mission.mistakes == 2, str(mission.mistakes))
	check("and the CPU socket is the one that explains", "for the processor" in mission.panel.text(), mission.panel.text())
	for pair in [["Cpu", "Motherboard/CpuSocket"], ["Ram", "Motherboard/RamSlot"], ["Ssd", "Motherboard/M2Slot"], ["Keyboard", "UsbPad"]]:
		await _place(mission, pair[0], _slot_top(mission, pair[1]))
	check("two mistakes: score 80, 3 attempts, 60 s", results == [[80, 60, 3]], str(results))


func _test_mission_part_homes_are_clear_of_slots() -> void:
	# A part that starts inside a slot's area would install itself on its first drop.
	var mission := await _fresh_bench(IdentifyComponents)
	var overlapping := []
	for zone in mission.zones:
		for body in zone.get_overlapping_bodies():
			if body is GrabbablePart:
				overlapping.append("%s in %s" % [body.name, zone.name])
	check("no part starts inside a slot", overlapping.is_empty(), str(overlapping))
