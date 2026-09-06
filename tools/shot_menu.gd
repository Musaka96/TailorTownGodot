extends SceneTree

## Visual check for the shelf + browse menu: loads the game, moves a few rolls
## onto the shelf, opens the browse menu, and screenshots it. NOT headless.
##   godot --path . --script res://tools/shot_menu.gd -- [out.png]

var _out := "res://.dev/menu.png"
var _frames := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_run()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var player: Node = main.find_child("Player", true, false)
	var shelf: Node = main.find_child("Shelf", true, false)
	var rolls := _find_rolls(main)

	# Place five rolls on the shelf using the real pick-up/place path.
	for i in min(5, rolls.size()):
		rolls[i].interact(player)
		shelf.interact(player)

	# Open the browse menu.
	shelf.interact(player)
	await process_frame

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


func _find_rolls(node: Node) -> Array:
	var out: Array = []
	if node.has_method("attach_to") and node.has_method("get_interaction_prompt"):
		out.append(node)
	for child in node.get_children():
		out += _find_rolls(child)
	return out
