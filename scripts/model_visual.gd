extends Node3D
## The visual of a part: an imported model, fitted to real size by
## tools/fit_models.gd. Hides any of the model's own nodes we don't want (for
## example the motherboard's M.2 heatsink, so an SSD can sit in the slot).

@export var hide_nodes: PackedStringArray = []


func _ready() -> void:
	for node_name in hide_nodes:
		var node := find_child(node_name, true, false)
		if node is Node3D:
			node.visible = false
