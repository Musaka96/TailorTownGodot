extends SceneTree

## Opens the phone ordering screen and screenshots it. NOT headless.
##   godot --path . --script res://tools/shot_phone.gd -- [out.png] [mode]
## mode: "custom" switches to the custom maker for the shot.

var _out := "res://.dev/phone.png"
var _custom := false
var _frames := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1 and args[1] == "custom":
		_custom = true
	_run()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var player: Node = main.find_child("Player", true, false)
	var phone: Node = main.find_child("Phone", true, false)
	phone.interact(player)
	await process_frame

	if _custom:
		# Nudge into custom mode (Mode row is first; A/D toggles).
		var menu = get_root().find_child("PhoneOrder", true, false)
		menu._adjust(1)   # toggle to Custom

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
