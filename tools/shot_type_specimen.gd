extends SceneTree

## Type specimen: every Style face at every step of the type scale, on each menu
## paper, so weights and sizes are tuned by eye in one sheet rather than menu by menu.
## Needs a rendering device — NOT --headless:
##   godot --path . --script res://tools/shot_type_specimen.gd -- [out.png]

const SAMPLE := "Navy Worsted Wool  $276  Day 12"

var _out := "res://.dev/type_specimen.png"
var _frames := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	var style: GDScript = load("res://ui/style.gd")
	var bg := ColorRect.new()
	bg.color = style.WALNUT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var cols := HBoxContainer.new()
	cols.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cols.add_theme_constant_override("separation", style.S2)
	bg.add_child(cols)
	var hud := root.get_node_or_null("UI") as CanvasLayer
	if hud != null:
		hud.visible = false
	var faces := {
		"display": style.font_display(),
		"body": style.font_body(),
		"medium": style.font_medium(),
		"bold": style.font_bold(),
		"caps": style.font_caps(),
	}
	var sizes: Array[int] = [
		style.T_CAPTION, style.T_BODY, style.T_VALUE, style.T_NAME, style.T_TITLE
	]
	for paper: Color in [style.CREAM, style.PAPER_MIRROR, style.CORK]:
		cols.add_child(_column(style, paper, faces, sizes))
	process_frame.connect(_on_frame)


func _column(style: GDScript, paper: Color, faces: Dictionary, sizes: Array[int]) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", style.bar(paper, 0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	for face_name: String in faces:
		for size in sizes:
			var lbl := Label.new()
			var text := SAMPLE.to_upper() if face_name == "caps" else SAMPLE
			lbl.text = "%s %d  %s" % [face_name, size, text]
			lbl.clip_text = true
			lbl.add_theme_font_override("font", faces[face_name])
			lbl.add_theme_font_size_override("font_size", size)
			lbl.add_theme_color_override("font_color", style.INK)
			box.add_child(lbl)
	return panel


func _on_frame() -> void:
	_frames += 1
	if _frames < 10:
		return
	var image := root.get_texture().get_image()
	image.save_png(_out)
	print("Saved ", _out)
	quit(0)
