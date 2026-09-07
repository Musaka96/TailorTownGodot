extends SceneTree

## Close-up of a roll, a cloth piece and a garment part to check the dynamic
## cloth material (colour + weave + pattern). NOT headless.
##   godot --path . --script res://tools/shot_closeup.gd

var _frames := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var roll: Node = load("res://entities/items/material_roll.tscn").instantiate()
	roll.material = load("res://data/materials/navy_worsted_pinstripe.tres")
	main.add_child(roll)
	roll.global_position = Vector3(3.6, 0.13, 1.5)
	roll.rotation_degrees = Vector3(0, 90, 0)

	var cloth: Node = load("res://entities/items/fabric_piece.tscn").instantiate()
	cloth.material = load("res://data/materials/brown_tweed_herringbone.tres")
	main.add_child(cloth)
	cloth.global_position = Vector3(4.4, 0.04, 1.5)

	var jacket: Node = load("res://entities/items/garment_piece.tscn").instantiate()
	jacket.material = load("res://data/materials/charcoal_worsted_pinstripe.tres")
	jacket.garment_type = 2
	jacket.stage = 3
	main.add_child(jacket)
	jacket.global_position = Vector3(5.2, 0.04, 1.5)

	var rig := get_root().find_child("CameraRig", true, false)
	rig.focus(Vector3(4.4, 0.85, 3.2), Vector3(4.4, 0.2, 1.5))
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 55:
		return
	var image := get_root().get_texture().get_image()
	if image:
		image.save_png("res://.dev/closeup.png")
		print("Saved res://.dev/closeup.png")
	quit(0)
