extends Node3D
## A flat 3D panel that shows a title and lines of text: mission intros,
## checklists, hints and the success screen.
##
## VR rule 4: normal screen UI (CanvasLayer) doesn't show up in the headset, so
## the text is drawn in a SubViewport and shown on a quad in the room. The
## panel builds its own nodes, so a scene only places it and calls show_text().

## Panel size in the room (meters).
@export var size := Vector2(0.6, 0.32)
## Pixels per meter for the text texture; higher is sharper and costs more.
@export var pixels_per_meter := 2000

var title: String = ""
var lines: PackedStringArray = []

var _viewport: SubViewport
var _title_label: Label
var _body_label: Label


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(size * pixels_per_meter)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	var background := PanelContainer.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.95)
	style.border_color = Color(0.35, 0.6, 0.95)
	style.set_border_width_all(6)
	style.set_corner_radius_all(24)
	style.set_content_margin_all(48)
	background.add_theme_stylebox_override("panel", style)
	_viewport.add_child(background)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	background.add_child(column)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 64)
	_title_label.add_theme_color_override("font_color", Color(1, 1, 1))
	column.add_child(_title_label)

	_body_label = Label.new()
	_body_label.add_theme_font_size_override("font_size", 40)
	_body_label.add_theme_color_override("font_color", Color(0.88, 0.9, 0.95))
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_body_label)

	var quad := QuadMesh.new()
	quad.size = size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _viewport.get_texture()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var screen := MeshInstance3D.new()
	screen.name = "Screen"
	screen.mesh = quad
	screen.material_override = material
	add_child(screen)

	_refresh()


## Shows a title and a list of lines (each line its own paragraph).
func show_text(new_title: String, new_lines: PackedStringArray) -> void:
	title = new_title
	lines = new_lines
	_refresh()


## Everything on the panel as plain text, for tests and logs.
func text() -> String:
	return "%s\n%s" % [title, "\n".join(lines)]


func _refresh() -> void:
	if _title_label == null:
		return
	_title_label.text = title
	_body_label.text = "\n".join(lines)
