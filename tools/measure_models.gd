extends SceneTree
## Prints each model's size (its bounding box), triangle count and mesh count, so
## it can be fitted to its part. Run: godot --headless --script res://tools/measure_models.gd

const MODELS := ["board", "cpu", "ram", "ssd_m2", "ssd_sata", "gpu", "psu", "monitor", "keyboard", "power_cable"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for name in MODELS:
		await _measure("res://models/%s/%s.glb" % [name, name], name)
	await _measure("res://models/desk/metal_office_desk_1k.gltf", "desk")
	quit()


func _measure(path: String, label: String) -> void:  # coroutine
	var scene: PackedScene = load(path)
	if scene == null:
		print("%s: could not load %s" % [label, path])
		return
	var root := scene.instantiate() as Node3D
	get_root().add_child(root)
	await process_frame
	var box := AABB()
	var first := true
	var tris := 0
	var meshes := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		meshes += 1
		var b: AABB = mi.global_transform * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var idx = arrays[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null else arrays[Mesh.ARRAY_VERTEX].size()) / 3
	print("%s: size x=%.4f y=%.4f z=%.4f  center=(%.3f, %.3f, %.3f)  tris=%d  meshes=%d" % [label, box.size.x, box.size.y, box.size.z, box.get_center().x, box.get_center().y, box.get_center().z, tris, meshes])
	root.queue_free()
