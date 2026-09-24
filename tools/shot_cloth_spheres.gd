extends "res://tools/shot_cloth_light.gd"

## Cloth spheres under the game's own look (the game_live stack of
## tools/shot_cloth_light.gd: shop environment, the shop's DirectionalLight3D as
## authored, camera DoF, outline pass, CRT PostFX). Eight SphereMesh balls per set, each
## wearing ClothMaterial.build(): set A suiting solids, B suiting patterns on worsted,
## C shirtings. Run once per phase; the phase names the raw rows:
##   timeout 300 godot --path . --script res://tools/shot_cloth_spheres.gd -- current
##   timeout 300 godot --path . --script res://tools/shot_cloth_spheres.gd -- new
## Rows go to .dev/sphere_rows/<phase>_<A|B|C>.png. Once both phases exist the "new"
## run lays out .dev/spheres_<A|B|C>.png (CURRENT above NEW, cloth names under each
## row) with tools/cloth_sheets.py and copies the new A row to spheres_A_full_new.png.
## Set D is shoe leather (ShoeMaterial.build) and renders on its own, one row, no
## CURRENT/NEW: -- D writes .dev/spheres_D.png and the raw row .dev/spheres_D_full.png.
## NOT headless (needs a GPU), and it must quit.

const SPHERE_DIR := "res://.dev/sphere_rows/"
const SPHERE_W := 1920
const SPHERE_H := 1080
const RADIUS := 0.42
const SPACING := 0.9
const COUNT := 8
## SphereMesh U runs once around the equator, so the weave tiles this many times round.
const SPHERE_UV := 4.0
# Straight on, a little above: [look-at, pitch down (deg), vertical fov]. The distance
# is solved so the row fills FILL of the frame width. 40 deg keeps the camera inside the
# game camera's 12 m depth-of-field far plane (a long lens from 14 m would blur it).
const SPHERE_TARGET := Vector3(0, RADIUS, 0)
const SPHERE_PITCH := 12.0
const SPHERE_FOV := 40.0
const FILL := 0.8
const SKY := Color("bcd0e4")
const WHITE := Color("f2f0e8")
const ECRU := Color("e9e1cf")
const LIGHT_GREY := Color("9a9ea6")
const CHARCOAL := Color("36393f")
const BURGUNDY := Color("5c1f2a")
const TAN := Color("c8b48a")
const OLIVE := Color("5c5a35")
# MaterialFactory.PATTERN_ACCENTS indices (0 = Auto contrast). NAVY, BROWN and MID_GREY
# come from shot_cloth_light.gd.
const AUTO := 0
const ACC_CHALK := 1
const ACC_CRIMSON := 3
const ACC_SKY := 5
# [fabric, pattern, cloth colour, accent (PATTERN_ACCENTS index or a Color), label]
const SETS := {
	"A":
	[
		[0, 0, NAVY, AUTO, "Worsted, navy"],
		[1, 0, LIGHT_GREY, AUTO, "Flannel, light grey"],
		[2, 0, BROWN, AUTO, "Tweed, brown"],
		[3, 0, CHARCOAL, AUTO, "Mohair, charcoal"],
		[4, 0, TAN, AUTO, "Linen, tan"],
		[5, 0, OLIVE, AUTO, "Cotton, olive"],
		[6, 0, WHITE, AUTO, "Poplin, white"],
		[7, 0, SKY, AUTO, "Oxford, sky"],
	],
	"B":
	[
		[0, 1, NAVY, ACC_CHALK, "Pinstripe, navy + chalk"],
		[0, 2, MID_GREY, AUTO, "Herringbone, mid grey"],
		[0, 3, CHARCOAL, ACC_CHALK, "Houndstooth, charcoal + chalk"],
		[0, 4, NAVY, ACC_CHALK, "Windowpane, navy + chalk"],
		[0, 5, LIGHT_GREY, AUTO, "Glen check, light grey"],
		[0, 6, BURGUNDY, AUTO, "Birdseye, burgundy"],
		[0, 7, LIGHT_GREY, AUTO, "Sharkskin, light grey"],
		[0, 8, CHARCOAL, AUTO, "Nailhead, charcoal"],
	],
	"C":
	[
		[6, 0, SKY, AUTO, "Poplin, sky"],
		[7, 0, WHITE, AUTO, "Oxford, white"],
		[5, 0, ECRU, AUTO, "Cotton, ecru"],
		[6, 9, WHITE, ACC_SKY, "Bengal stripe, sky on white poplin"],
		[7, 10, WHITE, Color("3a4a63"), "University stripe, blue on white oxford"],
		[6, 11, WHITE, Color("c98a96"), "Gingham, pink on white poplin"],
		[6, 12, ECRU, ACC_CRIMSON, "Tattersall, crimson on ecru poplin"],
		[6, 13, WHITE, ACC_SKY, "End-on-end, sky on white poplin"],
	],
}
# Solo sets (rendered alone with -- <set>): [ShoeMaterial colour id, finish, label].
const SOLO_SETS := {
	"D":
	[
		["black", "calf", "Calf, black"],
		["dark_brown", "calf", "Calf, dark brown"],
		["oxblood", "calf", "Calf, oxblood"],
		["tan", "calf", "Calf, tan"],
		["chestnut", "calf", "Calf, chestnut"],
		["black", "pebble", "Pebble, black"],
		["chestnut", "pebble", "Pebble, chestnut"],
		["black", "patent", "Patent, black"],
	],
}
const SET_TITLES := {
	"A": "SPHERES, SET A: SUITINGS",
	"B": "SPHERES, SET B: SUITING PATTERNS ON WORSTED",
	"C": "SPHERES, SET C: SHIRTINGS",
	"D": "SPHERES, SET D: LEATHER (procedural stand-in grain)",
}
const SET_ORDER: Array[String] = ["A", "B", "C"]

var _phase := "new"
var _spheres: Node3D
var _set_idx := 0
var _order: Array[String] = SET_ORDER


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_phase = args[0]
	if SOLO_SETS.has(_phase):
		_order = [_phase]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SPHERE_DIR))
	_vp = SubViewport.new()
	_vp.size = Vector2i(SPHERE_W, SPHERE_H)
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)
	_read_game()
	_build_stage()
	_spheres = Node3D.new()
	_world.add_child(_spheres)
	_place_sphere_camera()
	process_frame.connect(_on_frame)


func _place_sphere_camera() -> void:
	var row_w := (COUNT - 1) * SPACING + RADIUS * 2.0
	var half_h := tan(deg_to_rad(SPHERE_FOV) * 0.5)
	var half_w := half_h * float(SPHERE_W) / SPHERE_H
	var dist := row_w / FILL / (2.0 * half_w)
	var pitch := deg_to_rad(SPHERE_PITCH)
	_cam.fov = SPHERE_FOV
	var eye := SPHERE_TARGET + Vector3(0, sin(pitch), cos(pitch)) * dist
	_cam.look_at_from_position(eye, SPHERE_TARGET, Vector3.UP)


func _build_set(set_name: String) -> void:
	for c in _spheres.get_children():
		c.free()
	var items := _items(set_name)
	for i in items.size():
		var it: Array = items[i]
		var mesh := SphereMesh.new()
		mesh.radius = RADIUS
		mesh.height = RADIUS * 2.0
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		if SOLO_SETS.has(set_name):
			mi.material_override = ShoeMaterial.build(String(it[0]), String(it[1]), SPHERE_UV, true)
		else:
			mi.material_override = ClothMaterial.build(_sphere_cloth(it), SPHERE_UV, true)
		mi.position = _sphere_pos(i, items.size())
		_spheres.add_child(mi)


## The MaterialType the way the Cloth Lab builds one (scenes/dev/cloth_lab.gd _material).
func _sphere_cloth(it: Array) -> MaterialType:
	var cloth: Color = it[2]
	var mat := MaterialType.new()
	mat.fabric = int(it[0]) as Enums.Fabric
	mat.pattern = int(it[1]) as Enums.Pattern
	mat.cloth_color = cloth
	var accent: Variant = it[3]
	if accent is Color:
		mat.pattern_color = accent
	else:
		mat.pattern_color = MaterialFactory.pattern_color_for(cloth, int(accent))
	mat.display_name = "Sphere cloth"
	return mat


func _sphere_pos(i: int, n: int) -> Vector3:
	return Vector3((i - (n - 1) * 0.5) * SPACING, RADIUS, 0)


func _on_frame() -> void:
	_frames += 1
	if not _built:
		# Autoloads have run _ready by now.
		if _frames < 2:
			return
		_built = true
		_build_postfx()
		_apply_variant("game_live")
		_build_set(_order[0])
		_frames = 0
		return
	if _frames < SETTLE_FRAMES:
		return
	var set_name := _order[_set_idx]
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(_row_path(_phase, set_name))
	print("Saved ", _row_path(_phase, set_name))
	_set_idx += 1
	if _set_idx < _order.size():
		_build_set(_order[_set_idx])
		_frames = 0
		return
	quit(_compose_spheres())


func _row_path(phase: String, set_name: String) -> String:
	return SPHERE_DIR + "%s_%s.png" % [phase, set_name]


## Both phases on disk: CURRENT over NEW per set, cloth names under each row.
func _compose_spheres() -> int:
	if SOLO_SETS.has(_phase):
		return _compose_solo(_phase)
	if _phase != "new":
		print("shot_cloth_spheres: %s rows saved; run with -- new to compose." % _phase)
		return 0
	var sheets: Array[Dictionary] = []
	for set_name in SET_ORDER:
		var current := _row_path("current", set_name)
		if not FileAccess.file_exists(current):
			print("shot_cloth_spheres: no %s yet; run with -- current first." % current)
			return 1
		var below := _labels(set_name)
		(
			sheets
			. append(
				{
					"out": _dev("spheres_%s.png" % set_name),
					"width": SPHERE_W,
					"title": SET_TITLES[set_name],
					"subtitle": _summaries.get("game_live", ""),
					"rows":
					[
						{
							"image": ProjectSettings.globalize_path(current),
							"band": {"style": "before", "lines": ["CURRENT", "in game now"]},
							"below": below,
						},
						{
							"image": ProjectSettings.globalize_path(_row_path("new", set_name)),
							"band": {"style": "after", "lines": ["NEW", "shine fix"]},
							"below": below,
						},
					],
				}
			)
		)
	DirAccess.copy_absolute(
		ProjectSettings.globalize_path(_row_path("new", "A")), _dev("spheres_A_full_new.png")
	)
	return _run_composer(sheets)


## A solo set: its one row with the names under it, plus the raw frame.
func _compose_solo(set_name: String) -> int:
	var row := ProjectSettings.globalize_path(_row_path(_phase, set_name))
	var sheet := {
		"out": _dev("spheres_%s.png" % set_name),
		"width": SPHERE_W,
		"title": SET_TITLES[set_name],
		"subtitle": _summaries.get("game_live", ""),
		"rows": [{"image": row, "below": _labels(set_name)}],
	}
	DirAccess.copy_absolute(row, _dev("spheres_%s_full.png" % set_name))
	var sheets: Array[Dictionary] = [sheet]
	return _run_composer(sheets)


func _run_composer(sheets: Array[Dictionary]) -> int:
	var manifest := SPHERE_DIR + "manifest.json"
	var f := FileAccess.open(manifest, FileAccess.WRITE)
	f.store_string(JSON.stringify({"sheets": sheets}, "\t"))
	f.close()
	var out: Array = []
	var args := [ProjectSettings.globalize_path(COMPOSER), ProjectSettings.globalize_path(manifest)]
	var code := OS.execute("python", args, out, true)
	for line: String in out:
		print(line)
	print("shot_cloth_spheres: done (composer exit %d)." % code)
	return code


func _items(set_name: String) -> Array:
	return SOLO_SETS[set_name] if SOLO_SETS.has(set_name) else SETS[set_name]


## Each sphere's label and its centre across the frame (0..1), for the caption strip.
func _labels(set_name: String) -> Dictionary:
	var items := _items(set_name)
	var labels: Array[String] = []
	var xs: Array[float] = []
	for i in items.size():
		labels.append(String((items[i] as Array).back()))
		xs.append(_cam.unproject_position(_sphere_pos(i, items.size())).x / SPHERE_W)
	return {"labels": labels, "xs": xs}
