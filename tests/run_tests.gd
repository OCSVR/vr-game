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
	print("\n%s" % ("ALL PASSED" if _failures.is_empty() else "%d FAILED" % _failures.size()))
	quit(0 if _failures.is_empty() else 1)


func check(label: String, ok: bool, detail := "") -> void:
	print(("PASS  " if ok else "FAIL  ") + label + ("" if ok or detail == "" else "   [%s]" % detail))
	if not ok:
		_failures.append(label)


func _fresh_bench() -> Node3D:
	for child in root.get_children():
		child.queue_free()
	await process_frame
	var bench := Workbench.instantiate()
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
	var grabber = bench.get_node("MouseGrabber")
	var camera: Camera3D = bench.get_node("Camera3D")
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
