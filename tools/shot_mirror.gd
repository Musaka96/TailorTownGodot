extends SceneTree

## Screenshots the suit builder: whole-customer overview, then a part zoom.
## Also drops the three garment-part models in front so we can see them. NOT headless.
##   godot --path . --script res://tools/shot_mirror.gd

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
	var mirror: Node = main.find_child("Mirror", true, false)

	# Drop the three part models in front of the customer to check the shapes.
	var mats := [
		"navy_worsted_pinstripe", "brown_tweed_herringbone", "charcoal_worsted_solid",
	]
	for i in 3:
		var g: Node = load("res://entities/items/garment_piece.tscn").instantiate()
		g.material = load("res://data/materials/%s.tres" % mats[i])
		g.garment_type = i  # 0 shirt, 1 pants, 2 jacket
		g.stage = 3
		main.add_child(g)
		g.global_position = Vector3(2.1 + i * 0.85, 0.03, -5.2)

	var ui: Node = get_root().get_node("UI")
	ui.open_suit_builder(mirror, player)
	_menu = get_root().find_child("SuitBuilder", true, false)
	await process_frame
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _phase == 0 and _frames >= 55:
		_capture("res://.dev/mirror_overview.png")
		_menu._adjust(1)  # select the first part -> zoom
		_phase = 1
		_frames = 0
	elif _phase == 1 and _frames >= 55:
		_capture("res://.dev/mirror_zoom.png")
		quit(0)


func _capture(path: String) -> void:
	var image := get_root().get_texture().get_image()
	if image:
		image.save_png(path)
		print("Saved ", path)
