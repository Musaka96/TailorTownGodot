extends SceneTree

## Screenshots the suit builder: the suit tab, then the shirt tab (one camera for both),
## or (mode=street) the same customer framed the same way out on the street. NOT headless.
##   godot --path . --script res://tools/shot_mirror.gd [-- args]
##
## With no args it loads main.tscn, opens the builder with no customer and drops the
## three garment-part models in front so we can see them. Optional args:
##   scene=res://...tscn   the main scene to load; a customer is walked onto the mirror
##                         spot by the shop's own routing and fitted
##   out=res://.dev/name   output: <out>_suit.png / <out>_shirt.png, or <out>.png when
##                         only one shot is taken (tabs=suit, mode=street)
##   cloth=F,P,HEX[,A]     dress the customer's jacket and trousers in fabric F,
##                         pattern P (Enums ints), colour HEX and pattern accent A
##                         (MaterialFactory.PATTERN_ACCENTS index, 0 = auto)
##   tabs=suit             stop after the suit tab
##   seed=N                RNG seed for the customer's looks (default 7)
##   settle=N              minimum frames before a capture (default 120); the capture
##                         also waits for the camera to stop moving (capped)
##   size=WxH              window / capture size (default 1280x720)
##   mode=street           no builder: the customer stands outside the shop (at the
##                         DoorOutside waypoint, or spot=X,Z) facing the street, framed
##                         like the builder's portrait (centred), with the UI hidden
##   spot=X,Z  yaw=DEG     street mode: where the customer stands and faces (0 = +Z)
##   reno=all              grandpa's shop fully renovated (as tools/shot_grandpa.gd "all")
##   grain=short|full      street mode: photo grain on the town kit and stations, as a
##                         runtime override (tools/env_grain_override.gd, preview only)

const EnvGrain := preload("res://tools/env_grain_override.gd")
const DEFAULT_SCENE := "res://main.tscn"
const FACTORY_PATH := "res://data/scripts/material_factory.gd"
const DEFAULT_SIZE := Vector2i(1280, 720)
# Camera settle: this many frames in a row without the camera moving, within the cap.
const STILL_FRAMES := 10
const SETTLE_CAP := 300
const STILL_EPS := 0.0001
# The suit builder's portrait (ui/suit_builder.gd): centre height and visible span as
# fractions of the body height, and the camera's downward pitch.
const PORTRAIT := Vector2(0.65, 1.37)
const PITCH_DEG := 8.0
const DEFAULT_BODY_HEIGHT := 2.25

var _args := {}
var _size := DEFAULT_SIZE


func _initialize() -> void:
	_run()


func _run() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			_args[kv[0]] = kv[1]
	seed(int(_args.get("seed", "7")))
	if _args.has("size"):
		var wh: PackedStringArray = _args["size"].split("x")
		_size = Vector2i(int(wh[0]), int(wh[1]))
	DisplayServer.window_set_size(_size)
	var scene_path: String = _args.get("scene", DEFAULT_SCENE)
	var main: Node = load(scene_path).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	# Re-assert the capture size: the Settings autoload applies the saved window size.
	DisplayServer.window_set_size(_size)
	get_root().size = _size
	var ui: Node = get_root().get_node("UI")
	if ui.newspaper != null:
		ui.newspaper.close()  # the morning paper would cover the builder
	if _args.get("reno", "") == "all":
		_renovate_all()
	if _args.get("mode", "") == "street":
		await _street(main)
	else:
		await _mirror(main)
	quit(0)


## Grandpa's shop with every project finished and the room upgrades owned, as
## tools/shot_grandpa.gd stages it (no boards over the street front).
func _renovate_all() -> void:
	var reno: Node = get_root().get_node("Renovation")
	reno.reset()
	reno.debug_finish_all()
	var upgrades: Node = get_root().get_node("Upgrades")
	for id: String in ["shop_coffee", "shop_iron", "apprentice"]:
		upgrades.debug_set(id, true)
	upgrades.changed.emit()


func _mirror(main: Node) -> void:
	var player: Node = main.find_child("Player", true, false)
	var mirror: Node = main.find_child("Mirror", true, false)
	if _args.has("scene"):
		var cust: Node = _spawn_customer(main)
		if cust != null:
			await _route_to_mirror(main, mirror, cust)
	else:
		_drop_parts(main)
	var ui: Node = get_root().get_node("UI")
	ui.open_suit_builder(mirror, player)
	var menu: Node = get_root().find_child("SuitBuilder", true, false)
	await process_frame
	if _args.has("cloth") and mirror.customer != null:
		var mat: Resource = _cloth_material(_args["cloth"])
		var shirt: Resource = menu._part_material(0)  # Enums.GarmentType.SHIRT
		mirror.customer.wear_suit(mat, shirt, mat, 0, 0)
	var prefix: String = _args.get("out", "res://.dev/mirror")
	if _args.get("tabs", "") == "suit":
		await _settle()
		_capture(prefix + ".png")
		return
	await _settle()
	_capture(prefix + "_suit.png")
	menu._adjust(1)  # to the shirt tab
	await _settle()
	_capture(prefix + "_shirt.png")


## The seeded customer, dressed and standing outside the shop, framed like the builder.
func _street(main: Node) -> void:
	var ui: CanvasLayer = get_root().get_node("UI") as CanvasLayer
	ui.visible = false  # the way scenes/dev/cloth_refs.gd hides the HUD
	var cust: Node3D = _spawn_customer(main) as Node3D
	if cust == null:
		return
	var spot := _street_spot(main)
	var yaw := deg_to_rad(float(_args.get("yaw", "0")))
	cust.global_position = spot
	cust.rotation.y = yaw
	# Keep the player out of frame, on the street side (the camera's side of the shot).
	var player: Node3D = main.find_child("Player", true, false) as Node3D
	player.global_position = spot + Vector3(0.0, 0.0, 6.0).rotated(Vector3.UP, yaw)
	player.visible = false
	if _args.has("cloth"):
		var mat: Resource = _cloth_material(_args["cloth"])
		cust.wear_suit(mat, _default_shirt(), mat, 0, 0)
	for _i in 30:  # let the spawn settle into idle
		await process_frame
	var rig: Node = get_first_node_in_group("camera_rig")
	var cam := get_root().get_camera_3d()
	var height := _body_height(cust)
	var pose := _portrait_pose(cam, cust, height)
	rig.focus(pose.origin, pose.origin - pose.basis.z)
	if _args.has("grain"):
		var grain := EnvGrain.new(EnvGrain.dir_for(_args["grain"]))
		grain.apply(get_root())
		grain.report()
	await _settle()
	var path: String = _args.get("out", "res://.dev/street") + ".png"
	_capture(path)
	# Jacket brightness: the two fronts either side of the shirt's V, below the lapels.
	var chest := cust.global_position + Vector3(0.0, height * 0.28, 0.0)
	var side: Vector3 = cam.global_transform.basis.x * height * 0.08
	var luma := (
		(
			_luma_at(cam.unproject_position(chest - side))
			+ _luma_at(cam.unproject_position(chest + side))
		)
		* 0.5
	)
	print("street spot %s, jacket luma %.3f" % [spot, luma])
	print("shoes %s" % [cust.get("shoes")])


func _street_spot(main: Node) -> Vector3:
	if _args.has("spot"):
		var xz: PackedStringArray = _args["spot"].split(",")
		return Vector3(float(xz[0]), 0.0, float(xz[1]))
	var door: Node3D = main.find_child("DoorOutside", true, false) as Node3D
	return door.global_position if door != null else Vector3(0.65, 0.0, 12.1)


## The builder's portrait pose (ui/suit_builder.gd _frame_pose), centred on screen:
## no side panel or notepad in these shots, so the free area is the whole frame.
func _portrait_pose(cam: Camera3D, cust: Node3D, height: float) -> Transform3D:
	var front: Vector3 = cust.global_transform.basis.z
	front.y = 0.0
	front = front.normalized()
	var subject := cust.global_position + Vector3(0.0, height * PORTRAIT.x, 0.0)
	var span := height * PORTRAIT.y
	var vp := Vector2(_size)
	var aspect := vp.x / maxf(vp.y, 1.0)
	var tan_half := tan(deg_to_rad(cam.fov) * 0.5)
	var tan_v := tan_half if cam.keep_aspect == Camera3D.KEEP_HEIGHT else tan_half / aspect
	var pitch := deg_to_rad(PITCH_DEG)
	var dir := (-front * cos(pitch) + Vector3.DOWN * sin(pitch)).normalized()
	var basis := Basis.looking_at(dir, Vector3.UP)
	var depth := span / (2.0 * tan_v)
	return Transform3D(basis, subject - basis * Vector3(0.0, 0.0, -depth))


## Feet to top of hair from the visible meshes, as the builder measures it.
func _body_height(cust: Node3D) -> float:
	var base_y: float = cust.global_position.y
	var top := base_y
	for node in cust.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.is_visible_in_tree():
			top = maxf(top, (mesh.global_transform * mesh.get_aabb()).end.y)
	var h := top - base_y
	return h if h > 0.5 and h < 6.0 else DEFAULT_BODY_HEIGHT


## Wait at least settle=N frames, and until the camera has held still for STILL_FRAMES
## frames in a row (the rig eases into its focus pose), capped at SETTLE_CAP.
func _settle() -> void:
	var min_frames := int(_args.get("settle", "120"))
	var cap := maxi(SETTLE_CAP, min_frames)
	var still := 0
	var last := Transform3D()
	var frames := 0
	while frames < cap:
		await process_frame
		frames += 1
		var cam := get_root().get_camera_3d()
		var now := cam.global_transform if cam != null else Transform3D()
		var moved := (now.origin - last.origin).length() + _basis_delta(now.basis, last.basis)
		still = still + 1 if moved < STILL_EPS else 0
		last = now
		if frames >= min_frames and still >= STILL_FRAMES:
			break
	print("settled after %d frames (still for %d)" % [frames, still])


func _basis_delta(a: Basis, b: Basis) -> float:
	return (a.x - b.x).length() + (a.y - b.y).length() + (a.z - b.z).length()


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


## A seeded client from the shop's own CustomerManager (same looks every run), placed
## just inside the door. Null when the scene has no manager.
func _spawn_customer(main: Node) -> Node:
	var cm: Node = main.find_child("CustomerManager", true, false)
	var spot: Node3D = main.find_child("MirrorSpot", true, false)
	if cm == null or spot == null:
		push_warning("shot_mirror: no CustomerManager / MirrorSpot in the scene")
		return null
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
	return cust


## Walk the client onto the mirror spot by the shop's own routing (exact spot and
## facing), the way tools/shot_promo.gd seats one. Returns once they've arrived.
func _route_to_mirror(main: Node, mirror: Node, cust: Node) -> void:
	var cm: Node = main.find_child("CustomerManager", true, false)
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
	var factory: GDScript = load(FACTORY_PATH)
	var mat: Resource = load("res://data/scripts/material_type.gd").new()
	mat.fabric = int(parts[0])
	mat.pattern = int(parts[1]) if parts.size() > 1 else 0
	mat.cloth_color = cloth
	mat.pattern_color = factory.pattern_color_for(cloth, accent)
	mat.display_name = "Shot cloth"
	return mat


## The shirt the builder opens on (its first shirt fabric, colour and pattern), so the
## street shots match the mirror ones.
func _default_shirt() -> Resource:
	var menu: Node = get_root().find_child("SuitBuilder", true, false)
	var factory: GDScript = load(FACTORY_PATH)
	var enums: GDScript = load("res://data/scripts/enums.gd")
	var fabric: int = menu._available_fabrics(0)[0]  # 0 = Enums.GarmentType.SHIRT
	return factory.make(fabric, enums.patterns_for(0)[0], factory.colors_for(0)[0], 1.0)


## Mean luma (0..1) of a 24 px box of the frame around `view_at` (viewport coords).
func _luma_at(view_at: Vector2) -> float:
	var image := get_root().get_texture().get_image()
	# unproject_position() is in the stretched viewport's space, not the window's pixels.
	var at := view_at * Vector2(image.get_size()) / get_root().get_visible_rect().size
	var sum := 0.0
	var n := 0
	for y in range(int(at.y) - 12, int(at.y) + 12):
		for x in range(int(at.x) - 12, int(at.x) + 12):
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
				sum += image.get_pixel(x, y).get_luminance()
				n += 1
	return sum / maxf(n, 1.0)


func _capture(path: String) -> void:
	var image := get_root().get_texture().get_image()
	if image:
		image.save_png(path)
		print("Saved ", path, " ", image.get_size())
