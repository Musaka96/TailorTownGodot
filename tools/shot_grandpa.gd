extends SceneTree

## Visual check of grandpa's shop (paper folded away, camera settled). NOT headless.
##   godot --path . --script res://tools/shot_grandpa.gd -- [out.png] [x z] [stage]
## x z   where to stand the player (default: behind the desk)
## stage "day1" (default) | "all" (everything renovated, room upgrades owned) |
##       a project id: every project up to and including it is finished

var _out := "res://.dev/grandpa.png"
var _count := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var path := "res://scenes/world/grandpa/main_grandpa.tscn"
	var main: Node = load(path).instantiate()
	root.add_child(main)
	current_scene = main
	root.get_node("Locations").sync_to_scene(path)
	await process_frame
	await process_frame
	var ui: Node = root.get_node("UI")
	if ui.newspaper != null:
		ui.newspaper.close()
	if args.size() > 2:
		var player := main.find_child("Player", true, false) as Node3D
		player.global_position = Vector3(float(args[1]), 0.1, float(args[2]))
	_stage(args[3] if args.size() > 3 else "day1")
	process_frame.connect(_on_frame)


func _stage(stage: String) -> void:
	var reno: Node = root.get_node("Renovation")
	reno.reset()
	if stage == "day1":
		return
	if stage == "all":
		reno.debug_finish_all()
		var upgrades: Node = root.get_node("Upgrades")
		for id: String in ["shop_coffee", "shop_iron", "apprentice"]:
			upgrades.debug_set(id, true)
		upgrades.changed.emit()
		return
	while true:
		var done: String = reno.debug_finish_next()
		if done == "" or done == stage:
			return


func _on_frame() -> void:
	_count += 1
	if _count < 150:
		return
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(_out))
	quit()
