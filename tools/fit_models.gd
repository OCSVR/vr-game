extends SceneTree
## Writes models/<name>/<name>_visual.tscn for each model: the imported file,
## rotated and scaled to real size, with the origin at the part's snap point
## (build-plan VR rule 8). Run after changing a model or a fit below:
##   godot --headless --script res://tools/fit_models.gd
##
## rot: degrees about x, y, z.  size: target length of the longest side (m), or
## a Vector3 scale.  anchor: "bottom" puts the bottom-center at the origin,
## "keep" keeps the model's own origin.  hide: model nodes to hide.

const VISUAL_SCRIPT := "res://scripts/model_visual.gd"

const FITS := {
	"board": {"rot": Vector3.ZERO, "size": 0.305, "anchor": "keep", "hide": ["Cube_027_MATb_0"]},
	"cpu": {"rot": Vector3.ZERO, "size": 0.0375, "anchor": "bottom"},
	"ram": {"rot": Vector3(-90, 0, 0), "size": 0.133, "anchor": "bottom"},
	"ssd_m2": {"rot": Vector3(0, 90, 0), "size": 0.08, "anchor": "bottom"},
	"ssd_sata": {"rot": Vector3.ZERO, "size": 0.1, "anchor": "bottom"},
	"gpu": {"rot": Vector3(0, 90, 0), "size": 0.24, "anchor": "bottom"},
	"psu": {"rot": Vector3.ZERO, "size": 0.15, "anchor": "bottom"},
	"monitor": {"rot": Vector3.ZERO, "size": 0.54, "anchor": "bottom"},
	"keyboard": {"rot": Vector3.ZERO, "size": 0.32, "anchor": "bottom"},
	"power_cable": {"rot": Vector3.ZERO, "size": 0.16, "anchor": "bottom"},
	"desk": {"rot": Vector3.ZERO, "size": Vector3(0.6, 1.142857, 0.739020), "anchor": "bottom", "path": "res://models/desk/metal_office_desk_1k.gltf"},
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for name in FITS:
		await _fit(name, FITS[name])
	quit()


func _fit(name: String, fit: Dictionary) -> void:
	var path: String = fit.get("path", "res://models/%s/%s.glb" % [name, name])
	var model: Node3D = load(path).instantiate()
	var holder := Node3D.new()
	holder.name = name.to_pascal_case() + "Visual"
	get_root().add_child(holder)
	holder.add_child(model)
	model.owner = holder
	var r: Vector3 = fit.rot * PI / 180.0
	var basis := Basis.from_euler(r)
	model.transform = Transform3D(basis, Vector3.ZERO)
	await process_frame
	var box := _bounds(holder, model)
	var size = fit.size
	var scale3: Vector3
	if size is Vector3:
		scale3 = size
	else:
		scale3 = Vector3.ONE * (float(size) / maxf(box.size.x, maxf(box.size.y, box.size.z)))
	model.transform = Transform3D(basis.scaled_local(Vector3.ONE) * Basis.from_scale(Vector3.ONE), Vector3.ZERO)
	model.transform = Transform3D(Basis.from_scale(scale3) * basis, Vector3.ZERO)
	await process_frame
	box = _bounds(holder, model)
	if fit.anchor == "bottom":
		model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z)
	holder.set_script(load(VISUAL_SCRIPT))
	holder.set("hide_nodes", PackedStringArray(fit.get("hide", [])))
	await process_frame
	box = _bounds(holder, model)
	var packed := PackedScene.new()
	packed.pack(holder)
	var out := "res://models/%s/%s_visual.tscn" % [name, name]
	ResourceSaver.save(packed, out)
	print("%s -> %s  size=(%.4f, %.4f, %.4f)  bottom=%.4f" % [name, out, box.size.x, box.size.y, box.size.z, box.position.y])
	holder.queue_free()


func _bounds(holder: Node3D, model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var inv := holder.global_transform.affine_inverse()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var b: AABB = (inv * mi.global_transform) * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
