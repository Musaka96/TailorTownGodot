extends SceneTree

## Screenshots the suit builder: the suit tab, then the shirt tab (one camera for both).
## NOT headless.
##   godot --path . --script res://tools/shot_mirror.gd [-- args]
##
## With no args it loads main.tscn, opens the builder with no customer and drops the
## three garment-part models in front so we can see them. Optional args:
##   scene=res://...tscn   the main scene to load; a customer is walked onto the mirror
##                         spot by the shop's own routing and fitted
##   out=res://.dev/name   output prefix: writes <out>_suit.png / <out>_shirt.png
##   cloth=F,P,HEX[,A]     dress the fitted customer's jacket and trousers in fabric F,
##                         pattern P (Enums ints), colour HEX and pattern accent A
##                         (MaterialFactory.PATTERN_ACCENTS index, 0 = auto)
##   tabs=suit             stop after the suit tab
##   seed=N                RNG seed for the customer's looks (default 7)

const DEFAULT_SCENE := "res://main.tscn"
const SHOT_SIZE := Vector2i(1280, 720)
const SETTLE_FRAMES := 55

var _phase := 0
var _frames := 0
var _menu = null
var _args := {}


func _initialize() -> void:
	_run()


func _run() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			_args[kv[0]] = kv[1]
	seed(int(_args.get("seed", "7")))
	DisplayServer.window_set_size(SHOT_SIZE)
	var scene_path: String = _args.get("scene", DEFAULT_SCENE)
	var main: Node = load(scene_path).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	# Re-assert the capture size: the Settings autoload applies the saved window size.
	DisplayServer.window_set_size(SHOT_SIZE)
	get_root().size = SHOT_SIZE

	var player: Node = main.find_child("Player", true, false)
	var mirror: Node = main.find_child("Mirror", true, false)
	var ui: Node = get_root().get_node("UI")
	if ui.newspaper != null:
		ui.newspaper.close()  # the morning paper would cover the builder

	if _args.has("scene"):
		await _seat_customer(main, mirror)
	else:
		_drop_parts(main)

	ui.open_suit_builder(mirror, player)
	_menu = get_root().find_child("SuitBuilder", true, false)
	await process_frame
	if _args.has("cloth") and mirror.customer != null:
		var mat: Resource = _cloth_material(_args["cloth"])
		var shirt: Resource = _menu._part_material(0)  # Enums.GarmentType.SHIRT
		mirror.customer.wear_suit(mat, shirt, mat, 0, 0)
	process_frame.connect(_on_frame)


## Drop the three part models in front of the customer to check the shapes.
func _drop_parts(main: Node) -> void:
	var mats := [
		"navy_worsted_pinstripe",
		"brown_tweed_herringbone",
		"charcoal_worsted_solid",
	]
	for i in 3:
		var g: Node = load("res://entities/items/garment_piece.tscn").instantiate()
		g.material = load("res://data/materials/%s.tres" % mats[i])
		g.garment_type = i  # 0 shirt, 1 pants, 2 jacket
		g.stage = 3
		main.add_child(g)
		g.global_position = Vector3(2.1 + i * 0.85, 0.03, -5.2)


## A client walked onto the mirror spot by the shop's own routing (exact spot and
## facing), the way tools/shot_promo.gd seats one. Returns once they've arrived.
func _seat_customer(main: Node, mirror: Node) -> void:
	var cm: Node = main.find_child("CustomerManager", true, false)
	var spot: Node3D = main.find_child("MirrorSpot", true, false)
	if cm == null or spot == null:
		push_warning("shot_mirror: no CustomerManager / MirrorSpot in the scene")
		return
	for timer in cm.get_children():
		if timer is Timer:
			timer.stop()
	# Same client every run, so before / after shots compare like for like.
	var rng_seed := int(_args.get("seed", "7"))
	cm._rng.seed = rng_seed
	for autoload: String in ["Clientele", "FrontDesk"]:
		get_root().get_node(autoload)._rng.seed = rng_seed
	var start: Vector3 = spot.global_position + Vector3(-0.8, 0.0, 0.6)
	var cust: Node = cm._spawn(start, true)
	cust.global_position = start
	cm.route_to_mirror(cust)
	for _i in 300:
		if mirror.customer == cust:
			break
		await process_frame
	for _i in 30:  # let the walk blend back to idle
		await process_frame


## A MaterialType built like the Cloth Lab's (scenes/dev/cloth_lab.gd::_material()).
## The classes are loaded at runtime: their dependencies use autoloads, which a
## top-level --script can't resolve at compile time.
func _cloth_material(spec: String) -> Resource:
	var parts := spec.split(",")
	var cloth := Color(parts[2]) if parts.size() > 2 else Color("1b2a4a")
	var accent := int(parts[3]) if parts.size() > 3 else 0
	var factory: GDScript = load("res://data/scripts/material_factory.gd")
	var mat: Resource = load("res://data/scripts/material_type.gd").new()
	mat.fabric = int(parts[0])
	mat.pattern = int(parts[1]) if parts.size() > 1 else 0
	mat.cloth_color = cloth
	mat.pattern_color = factory.pattern_color_for(cloth, accent)
	mat.display_name = "Shot cloth"
	return mat


func _on_frame() -> void:
	_frames += 1
	var prefix: String = _args.get("out", "res://.dev/mirror")
	if _phase == 0 and _frames >= SETTLE_FRAMES:
		_capture(prefix + "_suit.png")
		if _args.get("tabs", "") == "suit":
			quit(0)
			return
		_menu._adjust(1)  # to the shirt tab
		_phase = 1
		_frames = 0
	elif _phase == 1 and _frames >= SETTLE_FRAMES:
		_capture(prefix + "_shirt.png")
		quit(0)


func _capture(path: String) -> void:
	var image := get_root().get_texture().get_image()
	if image:
		image.save_png(path)
		print("Saved ", path)
