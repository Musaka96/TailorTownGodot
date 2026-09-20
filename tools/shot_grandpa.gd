extends SceneTree

## Visual check of grandpa's shop (paper folded away, camera settled). NOT headless.
##   godot --path . --script res://tools/shot_grandpa.gd -- [out.png] [x z]   (player spot)

var _out := "res://.dev/grandpa.png"
var _count := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var main: Node = load("res://scenes/world/grandpa/main_grandpa.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ui: Node = root.get_node("UI")
	if ui.newspaper != null:
		ui.newspaper.close()
	if args.size() > 2:
		var player := main.find_child("Player", true, false) as Node3D
		player.global_position = Vector3(float(args[1]), 0.1, float(args[2]))
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_count += 1
	if _count < 150:
		return
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(_out))
	quit()
