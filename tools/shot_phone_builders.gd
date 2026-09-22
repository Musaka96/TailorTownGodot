extends SceneTree

## Opens the phone's Builders screen at grandpa's shop and screenshots it. NOT headless.
##   godot --path . --script res://tools/shot_phone_builders.gd -- [out.png]
##
## Sets up a spread of every row state so the shot shows them all: a finished project
## (front_window), one under way (front_lights), one available but unaffordable
## (workroom_build, once the front room is swept — the back rooms have no hand job of
## their own any more), and one locked by an earlier job (cloth_build, which waits on
## workroom_build).

var _out := "res://.dev/phone_builders.png"
var _frames := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_run()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var main: Node = load("res://scenes/world/grandpa/main_grandpa.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame

	# The morning paper auto-opens on day 1 — fold it away so it doesn't cover the shot.
	var paper: Node = get_root().find_child("Newspaper", true, false)
	if paper != null and paper.has_method("close"):
		paper.close()
	elif paper != null:
		paper.visible = false
	await process_frame

	var reno: Node = get_root().get_node("Renovation")
	var rep: Node = get_root().get_node("Reputation")
	var game: Node = get_root().get_node("GameState")

	reno.reset()
	for id: String in ["front_sheets", "front_sheets", "front_sheets"]:
		reno.clear_spot(id)
	for id: String in ["front_sweep", "front_sweep", "front_sweep"]:
		reno.clear_spot(id)
	rep.points = int(rep.TIERS[2]["at"])  # "Local Name" — reputation gates nothing here now

	game.money = 5000
	reno.order("front_window")  # 1 night — finish it below, so one row reads "Done"
	get_root().get_node("EventBus").day_began.emit(2)
	reno.order("front_lights")  # 1 night, left ticking — one row reads "under way"
	game.money = 250  # affords front_lights already ordered; not workroom_build ($900)

	# day_began (a new day) reopens the morning paper — fold it away again.
	await process_frame
	if paper != null and paper.has_method("close"):
		paper.close()
	elif paper != null:
		paper.visible = false
	await process_frame

	var menu: Control = get_root().find_child("PhoneOrder", true, false)
	menu.open(null, null)
	menu._move_row(3)  # HUB row 3 -> the Builders card
	menu._confirm()  # -> Screen.BUILDERS
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
