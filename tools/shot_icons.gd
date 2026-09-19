extends SceneTree

## Icon specimen: every shop-upgrade icon in its three states (available / owned /
## locked), large and at list-row size, so the set is judged by eye in one sheet.
## Needs a rendering device — NOT --headless:
##   godot --path . --script res://tools/shot_icons.gd -- [out.png]

var _out := "res://.dev/upgrade_icons.png"
var _frames := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var style: GDScript = load("res://ui/style.gd")
	var icon_script: GDScript = load("res://ui/craft/upgrade_icon.gd")
	var hud := root.get_node_or_null("UI") as CanvasLayer
	if hud != null:
		hud.visible = false
	var bg := ColorRect.new()
	bg.color = style.CREAM
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.position = Vector2(24, 20)
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 14)
	bg.add_child(grid)
	var upgrades := root.get_node("Upgrades")
	for id: String in upgrades.all_ids():
		grid.add_child(_cell(style, icon_script, id, str(upgrades.data(id).get("name", id))))
	process_frame.connect(_on_frame)


func _cell(style: GDScript, icon_script: GDScript, id: String, title: String) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(186, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	row.add_child(icon_script.make(id, 84.0, 0))
	row.add_child(icon_script.make(id, 36.0, 0))
	row.add_child(icon_script.make(id, 36.0, 1))
	row.add_child(icon_script.make(id, 36.0, 2))
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", style.T_CAPTION)
	lbl.add_theme_color_override("font_color", style.INK)
	box.add_child(lbl)
	return box


func _on_frame() -> void:
	_frames += 1
	if _frames < 10:
		return
	var image := root.get_texture().get_image()
	image.save_png(_out)
	print("Saved ", _out)
	quit(0)
