extends SceneTree

## Visual check for the fitting room in grandpa's shop: seats a customer at the mirror,
## opens the suit builder and saves a PNG — e.g. to see the shop-front walls held solid
## while the fitting is up. NOT headless.
##   godot --path . --script res://tools/shot_fitting.gd -- [out.png]

var _out := "res://.dev/fitting.png"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_run()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var main: Node = load("res://scenes/world/grandpa/main_grandpa.tscn").instantiate()
	root.add_child(main)
	for _i in 6:
		await process_frame
	var ui: Node = root.get_node("UI")
	if ui.newspaper != null:
		ui.newspaper.close()
	var cm: Node = get_first_node_in_group("customer_manager")
	for timer in cm.get_children():
		if timer is Timer:
			timer.stop()
	var mirror: Node3D = main.find_child("Mirror", true, false)
	var spot: Node3D = main.find_child("MirrorSpot", true, false)
	var player := main.find_child("Player", true, false) as Node3D
	player.global_position = spot.global_position + Vector3(0.8, 0.0, 1.0)
	for _i in 30:
		await process_frame  # the player is indoors: the shop front has faded
	var cust: Node = cm.call("_spawn", spot.global_position + Vector3(-0.8, 0.0, 0.6), true)
	cm.route_to_mirror(cust)
	for _i in 400:
		if mirror.get("customer") == cust:
			break
		await process_frame
	ui.open_suit_builder(mirror, player)
	for _i in 120:
		await process_frame
	get_root().get_texture().get_image().save_png(_out)
	print("Saved ", _out)
	quit(0)
