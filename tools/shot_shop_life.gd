extends SceneTree

## Visual check for the shop-life features by the door: the OPEN / CLOSED sign, and (with
## `wait`) a collector kept waiting with his patience bar. NOT headless.
##   godot --path . --script res://tools/shot_shop_life.gd -- [out.png] [sign|wait]

var _out := "res://.dev/shop_life.png"
var _what := "sign"
var _count := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_what = args[1]
	_run()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ui: Node = root.get_node("UI")
	if ui.newspaper != null:
		ui.newspaper.close()
	var player := main.find_child("Player", true, false) as Node3D
	var sign := main.find_child("DoorSign", true, false) as Node3D
	if _what == "wait":
		_keep_someone_waiting()
		var spot := main.find_child("CollectSpot", true, false) as Node3D
		player.global_position = spot.global_position + Vector3(-1.6, 0, 0.6)
	elif sign != null:
		player.global_position = sign.global_position + Vector3(-1.1, 0, -0.4)
	process_frame.connect(_on_frame)


## An unfinished order whose customer calls now.
func _keep_someone_waiting() -> void:
	var orders: Node = root.get_node("Orders")
	var suit := {"fabric": 0, "pattern": 1, "color": 0, "style_idx": 0}
	var order: Resource = orders.create_order("Mr. Ashdown", {2: suit}, 300, Color.WHITE)
	var manager: Node = get_first_node_in_group("customer_manager")
	if manager != null and manager.has_method("debug_send_collector"):
		manager.debug_send_collector(order)


func _someone_waiting() -> bool:
	for cust in get_nodes_in_group("customer"):
		if int(cust.get("_mode")) == 4:  # Customer.Mode.WAITING
			return true
	return false


func _on_frame() -> void:
	if _what == "wait" and not _someone_waiting():
		return  # still walking in
	_count += 1
	if _count < 120:
		return
	var image := get_root().get_texture().get_image()
	image.save_png(_out)
	print("Saved ", _out)
	quit(0)
