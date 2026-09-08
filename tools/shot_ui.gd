extends SceneTree

## Boots the game, opens one in-game menu, and captures it to a PNG so UI changes
## can be reviewed (and rated against the style guide) without a human at the
## window. Must run WITH a rendering device — NOT with --headless:
##
##   godot --path . --script res://tools/shot_ui.gd -- [menu] [out] [frames]
##
## menu:  phone | book | shelf | orders   (default: phone)
## out:   res:// PNG path                  (default: res://.dev/ui_<menu>.png)
## frames: extra settle frames after opening (default: 40)

var _menu := "phone"
var _out_path := ""
var _settle := 40
var _count := 0
var _opened := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_menu = args[0] if args.size() > 0 else "phone"
	_out_path = args[1] if args.size() > 1 else "res://.dev/ui_%s.png" % _menu
	_settle = int(args[2]) if args.size() > 2 else 40

	DisplayServer.window_set_size(Vector2i(1280, 720))
	var main := String(ProjectSettings.get_setting("application/run/main_scene", "res://main.tscn"))
	if change_scene_to_file(main) != OK:
		push_error("Could not load main scene")
		quit(1)
		return
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_count += 1
	# Let the world spin up, then open the menu, then settle before capturing.
	if _count == 30 and not _opened:
		_open()
		_opened = true
	if not _opened or _count < 30 + _settle:
		return

	var image := get_root().get_texture().get_image()
	if image == null:
		push_error("No framebuffer — run WITHOUT --headless")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out_path.get_base_dir())
	if image.save_png(_out_path) != OK:
		push_error("save_png failed")
		quit(1)
		return
	print("Saved ", _out_path)
	quit(0)


func _open() -> void:
	var ui := get_root().get_node_or_null("UI")
	if ui == null:
		push_error("UI autoload not found")
		quit(1)
		return
	var scene := get_root().get_node_or_null("Main")
	if scene == null:
		scene = get_root().get_child(get_root().get_child_count() - 1)
	match _menu:
		"book":
			ui.open_handbook(null)
		"orders":
			ui.open_orders_menu(null)
		"shelf":
			var sh := _find(scene, "Shelf")
			if sh != null:
				ui.open_shelf_menu(sh, _player())
		"worktable":
			var wt := _find(scene, "Worktable")
			if wt != null:
				ui.open_worktable(wt, _player(), null)
		"customer":
			var cust := _find(scene, "Customer")
			if cust != null:
				ui.open_customer_request(cust, _player())
		_:
			ui.open_phone(null, null)


func _find(scene: Node, cls: String) -> Node:
	if scene == null:
		return null
	var found := scene.find_children("*", cls, true, false)
	return found[0] if not found.is_empty() else null


func _player() -> Node:
	return get_first_node_in_group("player")
