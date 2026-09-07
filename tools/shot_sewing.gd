extends SceneTree

## Screenshots the sewing minigame. NOT headless.
##   godot --path . --script res://tools/shot_sewing.gd

var _frames := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var player: Node = main.find_child("Player", true, false)
	var machine: Node = main.find_child("SewingMachine", true, false)

	var piece: Node = load("res://entities/items/garment_piece.tscn").instantiate()
	piece.material = load("res://data/materials/charcoal_worsted_pinstripe.tres")
	piece.garment_type = 2  # JACKET
	piece.size = 2          # L
	piece.stage = 2         # CUT
	machine.get_node("Slot").add_child(piece)
	piece.transform = Transform3D.IDENTITY
	machine._item = piece

	var ui: Node = get_root().get_node("UI")
	ui.open_sewing(machine, player, piece)
	await process_frame
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 28:
		return
	var image := get_root().get_texture().get_image()
	if image:
		image.save_png("res://.dev/sewing.png")
		print("Saved res://.dev/sewing.png")
	quit(0)
