extends Node3D
## Lays every model out in a row, each scaled to 0.25 m, with a label and axes,
## to see which way each one faces. Open tools/preview_models.tscn and press F6.

const MODELS := ["board", "cpu", "ram", "ssd_m2", "ssd_sata", "gpu", "psu", "monitor", "keyboard", "power_cable"]

## Off: the raw imported models. On: the fitted *_visual.tscn scenes (what the game uses).
@export var fitted := false


func _ready() -> void:
	var paths := MODELS.map(func(n): return ("res://models/%s/%s_visual.tscn" if fitted else "res://models/%s/%s.glb") % [n, n])
	paths.append("res://models/desk/desk_visual.tscn" if fitted else "res://models/desk/metal_office_desk_1k.gltf")
	for i in paths.size():
		var holder := Node3D.new()
		add_child(holder)
		var model: Node3D = load(paths[i]).instantiate()
		holder.add_child(model)
		var box := _bounds(model)
		var s := 0.25 / maxf(box.size.x, maxf(box.size.y, box.size.z))
		model.scale = Vector3.ONE * s
		model.position = -box.get_center() * s
		holder.position = Vector3((i % 6) * 0.42 - 1.05, 0.0, -(i / 6) * 0.55)
		var label := Label3D.new()
		label.text = paths[i].get_file().get_basename()
		label.pixel_size = 0.001
		label.position = Vector3(0, 0.2, 0)
		holder.add_child(label)
		# Axes: red +x, green +y, blue +z
		for axis in [[Vector3.RIGHT, Color.RED], [Vector3.UP, Color.GREEN], [Vector3.BACK, Color.BLUE]]:
			var bar := MeshInstance3D.new()
			var m := BoxMesh.new()
			m.size = Vector3(0.004, 0.004, 0.004) + axis[0].abs() * 0.08
			var mat := StandardMaterial3D.new()
			mat.albedo_color = axis[1]
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.material = mat
			bar.mesh = m
			bar.position = axis[0] * 0.04 + Vector3(-0.15, -0.12, 0)
			holder.add_child(bar)


func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var b: AABB = mi.transform * mi.mesh.get_aabb()
		var p: Node = mi.get_parent()
		while p != root and p is Node3D:
			b = (p as Node3D).transform * b
			p = p.get_parent()
		box = b if first else box.merge(b)
		first = false
	return box
