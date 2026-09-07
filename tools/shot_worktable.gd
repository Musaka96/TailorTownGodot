extends SceneTree

## Screenshots the worktable config screen and the cutting minigame. NOT headless.
##   godot --path . --script res://tools/shot_worktable.gd

var _phase := 0
var _frames := 0
var _menu = null


func _initialize() -> void:
	_run()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var player: Node = main.find_child("Player", true, false)
	var worktable: Node = main.find_child("Worktable", true, false)

	# Put a fabric piece on the table directly.
	var piece: Node = load("res://entities/items/fabric_piece.tscn").instantiate()
	piece.material = load("res://data/materials/navy_worsted_pinstripe.tres")
	piece.length_m = 3.0
	worktable.get_node("Slot").add_child(piece)
	piece.transform = Transform3D.IDENTITY
	worktable._item = piece

	var ui: Node = get_root().get_node("UI")
	ui.open_worktable(worktable, player, piece)
	_menu = get_root().find_child("WorktableScreen", true, false)
	await process_frame
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _phase == 0 and _frames >= 25:
		_capture("res://.dev/worktable_config.png")
		_menu._start_cutting()
		_phase = 1
		_frames = 0
	elif _phase == 1 and _frames >= 45:
		_capture("res://.dev/worktable_cut.png")
		quit(0)


func _capture(path: String) -> void:
	var image := get_root().get_texture().get_image()
	if image:
		image.save_png(path)
		print("Saved ", path)
