extends SceneTree

## Renders a scene to a PNG so changes can be reviewed visually without a human
## watching the window. Because it captures the rendered framebuffer, it must run
## with a real rendering device — i.e. NOT with --headless:
##
##   godot --path . --script res://tools/screenshot.gd -- [scene] [out] [frames]
##
## Args (all optional, after the `--`):
##   scene   res:// path to load        (default: the project's main scene)
##   out     res:// path for the PNG     (default: res://.dev/screenshot.png)
##   frames  frames to settle before capture (default: 60)
##
## The window flashes briefly, captures, and quits. Output goes under .dev/,
## which is git-ignored.

var _scene_path: String
var _out_path: String
var _frames_to_wait: int
var _count := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_scene_path = args[0] if args.size() > 0 else String(
		ProjectSettings.get_setting("application/run/main_scene", "res://main.tscn"))
	_out_path = args[1] if args.size() > 1 else "res://.dev/screenshot.png"
	_frames_to_wait = int(args[2]) if args.size() > 2 else 60

	DisplayServer.window_set_size(Vector2i(1280, 720))
	var err := change_scene_to_file(_scene_path)
	if err != OK:
		push_error("Could not load scene: %s (err %d)" % [_scene_path, err])
		quit(1)
		return
	print("Rendering %s → %s ..." % [_scene_path, _out_path])
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_count += 1
	if _count < _frames_to_wait:
		return

	var image := get_root().get_texture().get_image()
	if image == null:
		push_error("No framebuffer — are you running WITHOUT --headless?")
		quit(1)
		return

	var dir := _out_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

	var err := image.save_png(_out_path)
	if err != OK:
		push_error("save_png failed: %d" % err)
		quit(1)
		return
	print("Saved ", _out_path)
	quit(0)
