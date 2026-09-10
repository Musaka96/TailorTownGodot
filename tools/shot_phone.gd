extends SceneTree

## Opens the phone ordering screen and screenshots it. NOT headless.
##   godot --path . --script res://tools/shot_phone.gd -- [out.png] [screen]
## screen: "hub" (default), "textiles", or "upgrades".

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
	if _screen == "textiles":
		menu._confirm()  # HUB row 0 -> Order Textiles
	elif _screen == "upgrades":
		menu._move_row(1)  # select second hub option
		menu._confirm()  # -> Shop Upgrades

	process_frame.connect(_on_frame)


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
