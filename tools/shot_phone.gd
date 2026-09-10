extends SceneTree

## Opens the phone ordering screen and screenshots it. NOT headless.
##   godot --path . --script res://tools/shot_phone.gd -- [out.png] [screen]
## screen: "hub" (default), "suppliers", "order", or "upgrades".

var _out := "res://.dev/phone.png"
var _screen := "hub"
var _frames := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_screen = args[1]
	_run()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	# The morning paper auto-opens on day 1 — fold it away so it doesn't cover the shot.
	var paper: Node = get_root().find_child("Newspaper", true, false)
	if paper != null and paper.has_method("close"):
		paper.close()
	elif paper != null:
		paper.visible = false
	await process_frame

	var player: Node = main.find_child("Player", true, false)
	var phone: Node = main.find_child("Phone", true, false)
	phone.interact(player)
	await process_frame

	var menu = get_root().find_child("PhoneOrder", true, false)
	if _screen == "suppliers":
		menu._confirm()  # HUB row 0 -> Suppliers phonebook
	elif _screen == "order":
		_shot_order(menu)
	elif _screen == "dye":
		_shot_dye(menu)
	elif _screen == "upgrades":
		menu._move_row(1)  # select second hub option
		menu._confirm()  # -> Shop Upgrades

	process_frame.connect(_on_frame)


## Order form showing a white cotton with a dark auto-contrast pinstripe.
func _shot_order(menu) -> void:
	menu._confirm()  # -> Suppliers
	menu._confirm()  # call Harrow's -> Order form
	menu._fabric = 5  # Cotton
	menu._color = 10  # White
	menu._pattern = 1  # Pinstripe
	menu._refresh()


## Premium supplier order form with the Pattern Dye row (needs reputation for Savile).
func _shot_dye(menu) -> void:
	var rep = get_root().get_node_or_null("/root/Reputation")
	if rep != null:
		rep.points = 999
	menu._confirm()  # -> Suppliers
	menu._move_row(1)  # highlight Northern
	menu._move_row(1)  # highlight Savile (now unlocked)
	menu._confirm()  # call Savile -> Order form
	menu._color = 10  # White
	menu._pattern = 4  # Windowpane
	menu._pattern_dye = 3  # Crimson
	menu._move_row(3)  # land on the Pattern Dye row
	menu._refresh()


func _on_frame() -> void:
	_frames += 1
	if _frames < 30:
		return
	var image := get_root().get_texture().get_image()
	if image:
		var dir := _out.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)
		image.save_png(_out)
		print("Saved ", _out)
	quit(0)
