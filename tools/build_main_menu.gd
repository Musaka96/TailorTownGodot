extends SceneTree

## Authors the 3D main-menu scene (scenes/menu/main_menu.tscn) ONCE, then it's a normal
## editable scene: the starting shop nested as an instance, a Camera that eases between
## Marker3D "Viewpoints" (one per menu page), and a left-anchored menu UI. Drag the
## viewpoint markers / restyle the panel in the editor freely — ui/main_menu.gd only eases
## the camera and fills the button list. Re-run to regenerate from scratch:
##   godot --headless --path . --script res://tools/build_main_menu.gd

const ROOM_SCENE := "res://scenes/world/shop_room.tscn"
const OUT := "res://scenes/menu/main_menu.tscn"
const MENU_SCRIPT := "res://ui/main_menu.gd"


func _initialize() -> void:
	var root := Node3D.new()
	root.name = "MainMenu"
	root.set_script(load(MENU_SCRIPT))
	root.process_mode = Node.PROCESS_MODE_ALWAYS

	# The starting shop, nested as an instance so it stays its own editable scene and the
	# menu can dress around it. PAUSABLE = a frozen backdrop while the (paused) menu is up.
	var shop: Node = load(ROOM_SCENE).instantiate()
	shop.name = "Shop"
	shop.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.add_child(shop)

	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.fov = 42.0
	cam.current = true
	cam.transform = _pose(Vector3(-1.2, 2.1, 7.8), Vector3(3.0, 1.35, 2.0))
	root.add_child(cam)

	# One viewpoint per menu page. Move these Marker3Ds in the editor to reframe a page;
	# the camera eases to the matching one (see ui/main_menu.gd VIEW_FOR).
	var vps := Node3D.new()
	vps.name = "Viewpoints"
	root.add_child(vps)
	vps.add_child(_marker("View_Main", Vector3(-1.2, 2.1, 7.8), Vector3(3.0, 1.35, 2.0)))
	vps.add_child(_marker("View_Load", Vector3(5.6, 1.9, 6.2), Vector3(3.2, 1.1, 2.6)))
	vps.add_child(_marker("View_Settings", Vector3(-2.6, 2.2, 6.6), Vector3(0.6, 1.2, 2.2)))

	root.add_child(_build_ui())

	_save(root, OUT)
	print("build_main_menu: done.")
	quit(0)


func _pose(pos: Vector3, look: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, pos).looking_at(look, Vector3.UP)


func _marker(nm: String, pos: Vector3, look: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.name = nm
	m.transform = _pose(pos, look)
	return m


# --- UI --------------------------------------------------------------------


func _build_ui() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "MenuLayer"
	var rootc := Control.new()
	rootc.name = "Root"
	rootc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rootc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rootc)

	var left := PanelContainer.new()
	left.name = "Left"
	left.anchor_top = 0.5
	left.anchor_bottom = 0.5
	left.grow_horizontal = Control.GROW_DIRECTION_END
	left.grow_vertical = Control.GROW_DIRECTION_BOTH
	left.offset_left = 48.0
	left.custom_minimum_size = Vector2(360, 0)
	left.add_theme_stylebox_override("panel", Style.skin_base(Style.BRASS, Style.CREAM, 20))
	rootc.add_child(left)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Style.S4)
	left.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", Style.S3)
	margin.add_child(content)

	var title := Style.title_label("TailorTown", Style.BRASS)
	title.name = "Title"
	title.add_theme_font_size_override("font_size", 40)
	content.add_child(title)

	var sub := Label.new()
	sub.name = "Sub"
	sub.text = "Bespoke tailoring on the Row"
	sub.add_theme_color_override("font_color", Style.INK_SOFT)
	sub.add_theme_font_size_override("font_size", 15)
	content.add_child(sub)

	content.add_child(HSeparator.new())

	var buttons := VBoxContainer.new()
	buttons.name = "Buttons"
	buttons.add_theme_constant_override("separation", Style.S2)
	content.add_child(buttons)
	return layer


# --- Save ------------------------------------------------------------------


func _save(root: Node, path: String) -> void:
	_set_owner(root, root)
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		push_error("pack failed: " + path)
		return
	if ResourceSaver.save(packed, path) != OK:
		push_error("save failed: " + path)
	else:
		print("wrote ", path)


func _set_owner(node: Node, owner_root: Node) -> void:
	for child in node.get_children():
		child.owner = owner_root
		# Own instance roots only — never recurse into a nested sub-scene, or it
		# becomes an editable-children override and corrupts the instance.
		if child.scene_file_path == "":
			_set_owner(child, owner_root)
