extends SceneTree

## Before/after shots of photo grain on grandpa's shop and the street: a RUNTIME PREVIEW,
## nothing baked. NOT headless.
##   python tools/cloth_refs/make_env_grain_preview.py [short]   (the grained textures first)
##   godot --path . --script res://tools/shot_env_grain.gd [-- preset=short stage=all|day1
##         settle=N]
##
## Loads main_grandpa.tscn, takes its views with the game's own materials (BEFORE), then
## swaps every surface whose texture set has a grained copy in the preset's folder for a
## duplicate using that albedo + normal (tools/env_grain_override.gd) and takes them
## again (AFTER). Frames go to <shots>/<view>_{before,after}.png, the AFTER frames also
## to .dev/<view>.png, and make_env_grain_preview.py compose builds the review sheet.
##
## preset=full (default): .dev/env_grain/, .dev/env_grain_shots/, .dev/env_grain_compare.png
##   env_shop_game   the gameplay camera, player just inside the door
##   env_shop_close  inside, low and level: back wall, wainscot, floor and the worktable
##   env_street      outside, low and level: the shop front, the pavement and the door
## preset=short: .dev/env_grain_short/, .dev/env_grain_shots_short/,
##   .dev/env_grain_short_compare.png
##   short_game_workroom    the follow camera, player at the worktable in the workroom
##   short_close_stations   low, ~1.8 m off the worktable and the sewing machine
##   short_close_wall       outside, low, 2 m off the render pier east of the door, 30 deg
##   short_close_cobbles    only when the nearest cobbles are away from that wall
##   short_street_customer  tools/shot_mirror.gd mode=street (seed 19, brown tweed), run
##                          twice as a child process: without and with grain=short

const EnvGrain := preload("res://tools/env_grain_override.gd")
const SCENE := "res://scenes/world/grandpa/main_grandpa.tscn"
const COMPOSER := "res://tools/cloth_refs/make_env_grain_preview.py"
const SIZE := Vector2i(1920, 1080)
const STILL_FRAMES := 10
const SETTLE_CAP := 400
const STILL_EPS := 0.0001
## short_close_wall: the render pier between the two sash windows east of the door (the
## front is mostly glass; this is its widest plain render), this far along the front
## from the door's centre, seen from this far off, turned this far toward the door.
const WALL_ALONG := 4.85
const WALL_DIST := 2.0
const WALL_ANGLE_DEG := -30.0
const WALL_EYE_Y := 0.9
const WALL_LOOK_Y := 1.0
## Cobbles further than this from the wall shot's spot get a frame of their own.
const COBBLE_NEAR := 3.0
## Only cobble surfaces covering at least this much ground (m2) count: a lane slab.
const COBBLE_MIN_AREA := 3.0
const STREET_CUSTOMER := [
	"mode=street",
	"seed=19",
	"cloth=2,0,6b4a2e",
	"size=1920x1080",
]

var _args := {}
var _main: Node
var _shots := "res://.dev/env_grain_shots/"


func _initialize() -> void:
	_run()


func _run() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			_args[kv[0]] = kv[1]
	var preset: String = _args.get("preset", "full")
	if preset == "short":
		_shots = "res://.dev/env_grain_shots_short/"
	var shots_abs := ProjectSettings.globalize_path(_shots)
	DirAccess.make_dir_recursive_absolute(shots_abs)
	for old in DirAccess.get_files_at(shots_abs):  # no stale optional frames in the sheet
		if old.ends_with(".png"):
			DirAccess.remove_absolute(shots_abs.path_join(old))
	DisplayServer.window_set_size(SIZE)
	_main = load(SCENE).instantiate()
	root.add_child(_main)
	current_scene = _main
	root.get_node("Locations").sync_to_scene(SCENE)
	await process_frame
	await process_frame
	DisplayServer.window_set_size(SIZE)  # the Settings autoload applies the saved size
	get_root().size = SIZE
	_stage(_args.get("stage", "all"))
	_quiet()
	await _shoot_all(preset, "before")
	var grain := EnvGrain.new(EnvGrain.dir_for(preset))
	grain.apply(get_root())
	await _shoot_all(preset, "after")
	grain.report()
	if preset == "short":
		_street_customer()
	_compose(preset)
	quit(0)


## The shop as it is on day 1, or (default) with every project finished and the room
## upgrades owned, as tools/shot_grandpa.gd stages it.
func _stage(stage: String) -> void:
	var reno: Node = get_root().get_node("Renovation")
	reno.reset()
	if stage != "all":
		return
	reno.debug_finish_all()
	var upgrades: Node = get_root().get_node("Upgrades")
	for id: String in ["shop_coffee", "shop_iron", "apprentice"]:
		upgrades.debug_set(id, true)
	upgrades.changed.emit()


## UI away (the way tools/shot_mirror.gd hides it) and no clients walking in.
func _quiet() -> void:
	var ui: CanvasLayer = get_root().get_node("UI") as CanvasLayer
	if ui.newspaper != null:
		ui.newspaper.close()
	ui.visible = false
	var cm: Node = _main.find_child("CustomerManager", true, false)
	if cm != null:
		for timer in cm.get_children():
			if timer is Timer:
				timer.stop()


# --- Views -------------------------------------------------------------------


func _shoot_all(preset: String, tag: String) -> void:
	if preset == "short":
		await _shoot_short(tag)
	else:
		await _shoot_full(tag)
	var player := _main.find_child("Player", true, false) as Node3D
	player.visible = true
	(get_first_node_in_group("camera_rig") as Node).unfocus()


func _shoot_full(tag: String) -> void:
	var player := _main.find_child("Player", true, false) as Node3D
	var door_in := _marker("DoorInside", Vector3(0.65, 0.0, 7.7))
	var door_out := _marker("DoorOutside", Vector3(0.65, 0.0, 9.6))
	var at := _station_pos("Worktable", Vector3(0.6, 0.0, 2.5))
	# the game camera, player just inside the door
	await _game_view(door_in + Vector3(0.0, 0.1, -0.4), "env_shop_game", tag)
	# inside, low and level, facing the back wall and the worktable. The player waits
	# behind the camera (inside, so the front walls stay cut the way they are in play).
	var eye := Vector3(at.x - 0.3, 1.0, at.z + 2.3)
	player.global_position = Vector3(eye.x, 0.1, door_in.z - 0.6)
	await _view(eye, eye + Vector3(0.0, 0.0, -1.0), "env_shop_close", tag)
	# the street, low and level, facing the shop front and the door
	var street_eye := Vector3(door_out.x + 0.4, 1.3, door_out.z + 5.2)
	player.global_position = street_eye + Vector3(0.0, -1.2, 1.0)
	await _view(street_eye, street_eye + Vector3(0.0, 0.0, -1.0), "env_street", tag)


func _shoot_short(tag: String) -> void:
	var player := _main.find_child("Player", true, false) as Node3D
	var table := _main.find_child("Worktable", true, false) as Node3D
	var sewing := _station_pos("SewingMachine", table.global_position)
	var front := _flat(table.global_transform.basis.z)
	# (a) the follow camera, the player standing at the worktable, facing it
	var stand := table.global_position + front * 1.0 + Vector3(0.0, 0.1, 0.0)
	var model := player.get_node_or_null("Model") as Node3D
	if model != null:
		model.rotation.y = atan2(-front.x, -front.z)
	await _game_view(stand, "short_game_workroom", tag)
	# (b) low, ~1.8 m off the front of the worktable and the sewing machine; the player
	# waits behind the camera, inside the workroom
	var mid := (table.global_position + sewing) * 0.5
	var eye := mid + front * 2.25 + Vector3(0.0, 1.3, 0.0)
	player.global_position = eye + front * 0.8 + Vector3(0.0, -1.2, 0.0)
	await _view(eye, mid + Vector3(0.0, 0.8, 0.0), "short_close_stations", tag)
	# (c) outside, 2 m off the render beside the door at 30 degrees, low
	var door := _marker("DoorOutside", Vector3(0.65, 0.0, 9.6))
	var shop := _main.find_child("GrandpaShop", true, false) as Node3D
	var face_z: float = shop.global_position.z if shop != null else 8.34
	var spot := Vector3(door.x + WALL_ALONG, WALL_LOOK_Y, face_z + 0.15)
	var ang := deg_to_rad(WALL_ANGLE_DEG)
	var wall_eye := spot + Vector3(sin(ang), 0.0, cos(ang)) * WALL_DIST
	wall_eye.y = WALL_EYE_Y
	player.visible = false
	player.global_position = wall_eye + Vector3(0.0, -0.65, 1.5)
	await _view(wall_eye, spot, "short_close_wall", tag)
	# (d) the nearest cobbles, when they are not at that wall
	var cobble := _nearest_cobble(spot)
	var far := Vector2(cobble.x - spot.x, cobble.z - spot.z).length()
	if tag == "before":
		print("nearest cobble surface point %s, %.2f m from the wall spot" % [cobble, far])
	if cobble != Vector3.INF and far > COBBLE_NEAR:
		var away := _flat(cobble - door)
		var c_eye := cobble + away * 1.8 + Vector3(0.0, 1.0, 0.0)
		player.global_position = c_eye + away * 1.0 + Vector3(0.0, -0.9, 0.0)
		await _view(c_eye, cobble + Vector3(0.0, 0.1, 0.0), "short_close_cobbles", tag)


## The follow camera with the player standing at `at`.
func _game_view(at: Vector3, view: String, tag: String) -> void:
	var player := _main.find_child("Player", true, false) as Node3D
	player.visible = true
	player.global_position = at
	(get_first_node_in_group("camera_rig") as Node).unfocus()
	await _settle()
	_capture(view, tag)
	if tag == "before":
		var cam := get_root().get_camera_3d()
		print("%s: player %s, camera %s" % [view, at, cam.global_position])


## The camera at `eye` looking at `look`, the player hidden.
func _view(eye: Vector3, look: Vector3, view: String, tag: String) -> void:
	var player := _main.find_child("Player", true, false) as Node3D
	player.visible = false
	(get_first_node_in_group("camera_rig") as Node).focus(eye, look)
	await _settle()
	_capture(view, tag)
	if tag == "before":
		print("%s: eye %s look %s" % [view, eye, look])


func _marker(marker_name: String, fallback: Vector3) -> Vector3:
	var node := _main.find_child(marker_name, true, false) as Node3D
	return node.global_position if node != null else fallback


func _station_pos(station: String, fallback: Vector3) -> Vector3:
	var node := _main.find_child(station, true, false) as Node3D
	return node.global_position if node != null else fallback


func _flat(v: Vector3) -> Vector3:
	var f := Vector3(v.x, 0.0, v.z)
	return f.normalized() if f.length() > 0.001 else Vector3(0.0, 0.0, 1.0)


## The centre of the cobble surface nearest `to` (Vector3.INF when there is none). The
## town kit lays cobbles as the back lane's 2 m sidewalk slabs and as the 1.2 x 1 m slabs
## of the garden paths between the houses; only the lane counts (COBBLE_MIN_AREA).
func _nearest_cobble(to: Vector3) -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	for node in _main.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			if mat == null or mat.resource_name != "cobble":
				continue
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			var box := AABB(mi.global_transform * verts[0], Vector3.ZERO)
			for v in verts:
				box = box.expand(mi.global_transform * v)
			var d := box.get_center().distance_squared_to(to)
			if box.size.x * box.size.z >= COBBLE_MIN_AREA and d < best_d:
				best_d = d
				best = box.get_center()
	return best


## At least settle=N frames, then until the camera has held still STILL_FRAMES in a row
## (capped), as tools/shot_mirror.gd waits.
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


func _capture(view: String, tag: String) -> void:
	var image := get_root().get_texture().get_image()
	if image == null:
		push_error("shot_env_grain: no frame for %s" % view)
		return
	var path := ProjectSettings.globalize_path("%s%s_%s.png" % [_shots, view, tag])
	image.save_png(path)
	print("Saved ", path, " ", image.get_size())
	if tag == "after":
		image.save_png(ProjectSettings.globalize_path("res://.dev/%s.png" % view))


# --- Child runs and the sheet ------------------------------------------------


## tools/shot_mirror.gd's street framing, as its own Godot run (it is a SceneTree script
## of its own): once as the game draws it, once with grain=short.
func _street_customer() -> void:
	var base := _shots + "short_street_customer"
	for tag: String in ["before", "after"]:
		var args := PackedStringArray(
			["--path", ProjectSettings.globalize_path("res://"), "--script"]
		)
		args.append("res://tools/shot_mirror.gd")
		args.append("--")
		args.append("scene=" + SCENE)
		args.append_array(PackedStringArray(STREET_CUSTOMER))
		args.append("out=%s_%s" % [base, tag])
		if _args.get("stage", "all") == "all":
			args.append("reno=all")  # the same shop as the other frames
		if tag == "after":
			args.append("grain=short")
		var out: Array = []
		var code := OS.execute(OS.get_executable_path(), args, out, true)
		# its Saved/street lines and the per-set counts (not the long unmatched list)
		var counting := false
		for chunk: String in out:
			for line in chunk.split("\n"):
				if line.contains("matched nothing"):
					counting = false
				if counting or line.begins_with("Saved") or line.begins_with("street spot"):
					print("  [shot_mirror] ", line.strip_edges())
				if line.contains("surfaces grained"):
					counting = true
		if code != 0:
			push_error("shot_env_grain: shot_mirror (%s) exited %d" % [tag, code])
	var after := ProjectSettings.globalize_path(base + "_after.png")
	if FileAccess.file_exists(after):
		var image := Image.load_from_file(after)
		image.save_png(ProjectSettings.globalize_path("res://.dev/short_street_customer.png"))


func _compose(preset: String) -> void:
	var out: Array = []
	var args := [ProjectSettings.globalize_path(COMPOSER), "compose"]
	if preset == "short":
		args.append("short")
	var code := OS.execute("python", args, out, true)
	for line: String in out:
		print(line.strip_edges())
	if code != 0:
		push_error("shot_env_grain: composer exited %d" % code)
