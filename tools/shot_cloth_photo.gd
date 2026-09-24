extends SceneTree

## Cloth Look v3 review sheets: the scanned photo grain + cloth lighting against the
## v2 look it replaces, on the real garment meshes (straight from the glb, as in
## tools/shot_cloth_compare.gd) and on material_roll bolts. Each sheet stacks its
## rows (v2 on top, photo below) into one PNG in .dev/, with a title strip and a
## BEFORE (grey) / AFTER (green) band down each row's left, drawn by
## tools/cloth_sheets.py (PIL) from the raw rows in .dev/cloth_rows/:
##   cloth_photo_suit_<front|raking|gameplay>.png   5 suitings, navy solid
##   cloth_photo_patterns_<front|gameplay>.png      5 worsted patterns, photo only
##   cloth_photo_rolls.png                          8 fabrics on bolts
##   cloth_photo_shirtings.png                      shirting solids + stripes on bolts
## "v2" = the photo-look material with the v3 dials zeroed and the v2 globals put back
## (tools/build_cloth_materials.gd). NOT headless:
##   godot --path . --script res://tools/shot_cloth_photo.gd

const GLB := "res://assets/characters/CHARTGEN1.glb"
# Loaded lazily: its script chain reaches the Config autoload, which a --script
# SceneTree has not registered yet when its constants compile.
const ROLL_SCENE := "res://entities/items/material_roll.tscn"
const WIDTH := 1600
const HEIGHT := 900
const FIG_SPACING := 2.3
const ROLL_SPACING := 0.45
const FIG_UV_SCALE := 6.0  # CharacterRig.CLOTH_UV_SCALE, as shot_cloth_compare uses
# The v2 look, written over the photo-look material for the top row.
const V2 := {
	"grain_strength": 0.0,
	"pattern_fuzz": 0.0,
	"wrap": 0.0,
	"sheen_strength": 0.0,
	"aniso": 0.0,
	"fabric_strength": 0.5,
	"normal_depth": 1.8,
}
# Cloth colours (MaterialFactory.COLORS where the mill has one).
const NAVY := Color("1b2a4a")
const MID_GREY := Color("6e7279")
const LIGHT_GREY := Color("9a9ea6")
const CHARCOAL := Color("36393f")
const BURGUNDY := Color("5c1f2a")
const BROWN := Color("5a4633")
const TAN := Color("c8b48a")
const OLIVE := Color("5c5a35")
const WHITE := Color("f2f0e8")
const SKY := Color("bcd0e4")
const ECRU := Color("e9e1cf")
# Stripe / check threads: MaterialFactory.PATTERN_ACCENTS chalk and sky, plus a clear
# shirt blue and a gingham pink (the mill's pale pink vanishes on white).
const CHALK := Color("f0efe6")
const SKY_THREAD := Color("9fc0e0")
const SHIRT_BLUE := Color("4a6fa8")
const GINGHAM_PINK := Color("e09aa8")
# [sun rotation, camera position, look-at, fov, crop rect (y, height) of the capture].
# The figure setups are shot_cloth_compare's, pulled back / widened so all five fit
# the 16:9 frame, then cropped to the band the figures stand in.
const SETUPS := {
	"front": [Vector3(-38, -32, 0), Vector3(0, 1.2, 11.0), Vector3(0, 1.0, 0), 35.0, [250, 380]],
	"raking": [Vector3(-10, -75, 0), Vector3(0, 1.2, 11.0), Vector3(0, 1.0, 0), 35.0, [250, 380]],
	# The real camera-rig angle (pitch -55 deg, 7.7 m out), fov widened to fit the row.
	"gameplay":
	[Vector3(-38, -32, 0), Vector3(0, 6.27, 4.39), Vector3(0, 0.9, 0), 54.0, [290, 300]],
	"rolls": [Vector3(-38, -32, 0), Vector3(0, 1.2, 3.8), Vector3(0, 0.12, 0), 30.0, [250, 330]],
	# Closer, for the shirting stripes and checks (six bolts).
	"shirt_rolls":
	[Vector3(-38, -32, 0), Vector3(0, 1.05, 3.3), Vector3(0, 0.12, 0), 30.0, [230, 370]],
}
# [kind, setup, looks, out file, sheet title].
const JOBS := [
	["suit", "front", ["v2", "photo"], "cloth_photo_suit_front.png", "SUIT, FRONT LIGHT"],
	["suit", "raking", ["v2", "photo"], "cloth_photo_suit_raking.png", "SUIT, RAKING LIGHT"],
	[
		"suit",
		"gameplay",
		["v2", "photo"],
		"cloth_photo_suit_gameplay.png",
		"SUIT, GAMEPLAY CAMERA",
	],
	["patterns", "front", ["photo"], "cloth_photo_patterns_front.png", "PATTERNS, FRONT LIGHT"],
	[
		"patterns",
		"gameplay",
		["photo"],
		"cloth_photo_patterns_gameplay.png",
		"PATTERNS, GAMEPLAY CAMERA",
	],
	["rolls", "rolls", ["v2", "photo"], "cloth_photo_rolls.png", "CLOTH ROLLS"],
	[
		"shirtings",
		"shirt_rolls",
		["v2", "photo"],
		"cloth_photo_shirtings.png",
		"SHIRTINGS ON ROLLS"
	],
]
# The label band per look (tools/cloth_sheets.py styles).
const BANDS := {
	"v2": {"style": "before", "lines": ["BEFORE", "previous cloth (v2)"]},
	"photo": {"style": "after", "lines": ["AFTER", "scanned grain (v3)"]},
}
const ROW_DIR := "res://.dev/cloth_rows/"
const COMPOSER := "res://tools/cloth_sheets.py"
const SETTLE_FRAMES := 12

var _vp: SubViewport
var _world: Node3D
var _content: Node3D
var _sun: DirectionalLight3D
var _cam: Camera3D
var _labels: CanvasLayer
var _col_labels: Array[Label] = []
var _meshes := {}
var _rows: Array[Dictionary] = []
var _sheets: Array[Dictionary] = []
var _job := 0
var _look := 0
var _frames := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROW_DIR))
	_vp = _make_viewport()
	root.add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)
	_add_environment()
	_meshes = _garment_meshes()
	_start_capture()
	process_frame.connect(_on_frame)


## Renders into a fixed-size SubViewport with its own world, not the window: the OS
## may clamp the window below HEIGHT, and the game autoloads' HUD / post-FX layers
## live on the root viewport, so they stay out of the sheet.
func _make_viewport() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(WIDTH, HEIGHT)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	return vp


func _add_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.33, 0.36, 0.42)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 0.95)
	env.ambient_light_energy = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_world.add_child(_sun)
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor_mesh.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.42, 0.4, 0.38)
	fm.roughness = 1.0
	floor_mesh.material_override = fm
	_world.add_child(floor_mesh)
	_cam = Camera3D.new()
	_world.add_child(_cam)
	_cam.make_current()
	_labels = CanvasLayer.new()
	_labels.layer = 100
	_vp.add_child(_labels)


## The garment Mesh resources straight out of the glb (bind pose on a bare
## MeshInstance3D — good enough to judge fabric).
func _garment_meshes() -> Dictionary:
	var scene: Node = (load(GLB) as PackedScene).instantiate()
	var out := {}
	for mesh_name: String in ["jacket", "legs", "shirt"]:
		var mi := scene.find_child(mesh_name, true, false) as MeshInstance3D
		out[mesh_name] = mi.mesh
	scene.free()
	return out


func _label(pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = 8
	ls.outline_color = Color(0.08, 0.08, 0.1)
	l.label_settings = ls
	_labels.add_child(l)
	return l


# --- Subjects ----------------------------------------------------------------


## [MaterialType, column label] per slot for a job kind.
func _items(kind: String) -> Array:
	match kind:
		"suit":
			return [
				[_cloth(0, 0, NAVY, CHALK), "Worsted"],
				[_cloth(1, 0, NAVY, CHALK), "Flannel"],
				[_cloth(2, 0, NAVY, CHALK), "Tweed"],
				[_cloth(3, 0, NAVY, CHALK), "Mohair"],
				[_cloth(4, 0, NAVY, CHALK), "Linen"],
			]
		"patterns":
			return [
				[_cloth(0, 1, NAVY, CHALK), "Pinstripe"],
				[_cloth(0, 2, MID_GREY, _auto(MID_GREY)), "Herringbone"],
				[_cloth(0, 3, CHARCOAL, CHALK), "Houndstooth"],
				[_cloth(0, 5, LIGHT_GREY, _auto(LIGHT_GREY)), "Glen check"],
				[_cloth(0, 6, BURGUNDY, _auto(BURGUNDY)), "Birdseye"],
			]
		"rolls":
			return [
				[_cloth(0, 0, NAVY, CHALK), "Worsted"],
				[_cloth(1, 0, MID_GREY, CHALK), "Flannel"],
				[_cloth(2, 0, BROWN, CHALK), "Tweed"],
				[_cloth(3, 0, CHARCOAL, CHALK), "Mohair"],
				[_cloth(4, 0, TAN, CHALK), "Linen"],
				[_cloth(5, 0, OLIVE, CHALK), "Cotton"],
				[_cloth(6, 0, WHITE, CHALK), "Poplin"],
				[_cloth(7, 0, SKY, CHALK), "Oxford"],
			]
	return [
		[_cloth(6, 0, WHITE, CHALK), "Poplin"],
		[_cloth(7, 0, SKY, CHALK), "Oxford"],
		[_cloth(5, 0, ECRU, CHALK), "Cotton"],
		[_cloth(7, 10, WHITE, SHIRT_BLUE), "Univ. stripe"],
		[_cloth(6, 9, WHITE, SKY_THREAD), "Bengal"],
		[_cloth(6, 11, WHITE, GINGHAM_PINK), "Gingham"],
	]


func _cloth(fabric: int, pattern: int, cloth: Color, accent: Color) -> MaterialType:
	var mat := MaterialType.new()
	mat.fabric = fabric as Enums.Fabric
	mat.pattern = pattern as Enums.Pattern
	mat.cloth_color = cloth
	mat.pattern_color = accent
	mat.roll_length_m = 20.0
	mat.display_name = "Photo cloth"
	return mat


## The mill's auto-contrast thread for a cloth (MaterialFactory accent 0).
func _auto(cloth: Color) -> Color:
	return MaterialFactory.pattern_color_for(cloth, 0)


func _is_figure(kind: String) -> bool:
	return kind == "suit" or kind == "patterns"


func _slot(kind: String, i: int, n: int) -> Vector3:
	var spacing := FIG_SPACING if _is_figure(kind) else ROLL_SPACING
	return Vector3((i - (n - 1) * 0.5) * spacing, 0, 0)


func _build_content(kind: String, look: String) -> void:
	if _content != null:
		_content.queue_free()
	_content = Node3D.new()
	_world.add_child(_content)
	var items := _items(kind)
	for i in items.size():
		var mat: MaterialType = items[i][0]
		var pos := _slot(kind, i, items.size())
		if _is_figure(kind):
			_content.add_child(_figure(ClothMaterial.build(mat, FIG_UV_SCALE, true), pos))
		else:
			var roll := (load(ROLL_SCENE) as PackedScene).instantiate() as Node3D
			roll.set("material", mat)
			_content.add_child(roll)
			# The bolt lies centred on its origin: lift it to rest on the floor.
			roll.position = pos + Vector3(0, roll.call("radius"), 0)
	if look == "v2":
		_to_v2(_content)


func _figure(cloth: ShaderMaterial, pos: Vector3) -> Node3D:
	var fig := Node3D.new()
	fig.position = pos
	for mesh_name: String in ["jacket", "legs", "shirt"]:
		var mi := MeshInstance3D.new()
		mi.mesh = _meshes[mesh_name]
		if mesh_name == "shirt":
			var flat := StandardMaterial3D.new()
			flat.albedo_color = Color(0.92, 0.92, 0.9)
			flat.roughness = 1.0
			mi.material_override = flat
		else:
			mi.material_override = cloth
		fig.add_child(mi)
	return fig


## Every cloth material under `node` (override or per-surface) back to the v2 look.
func _to_v2(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mats: Array[Material] = [mi.material_override]
		if mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				mats.append(mi.get_surface_override_material(s))
		for m: Material in mats:
			var sm := m as ShaderMaterial
			if sm != null and _is_cloth(sm):
				for key: String in V2:
					sm.set_shader_parameter(key, V2[key])
	for c in node.get_children():
		_to_v2(c)


func _is_cloth(sm: ShaderMaterial) -> bool:
	return sm.shader == ClothMaterial.SHADER or sm.shader == ClothMaterial.SHADER_TRIPLANAR


# --- Capture loop ------------------------------------------------------------


func _start_capture() -> void:
	var job: Array = JOBS[_job]
	var kind: String = job[0]
	var setup: Array = SETUPS[job[1]]
	var look: String = job[2][_look]
	_build_content(kind, look)
	_sun.rotation_degrees = setup[0]
	_cam.fov = setup[3]
	_cam.look_at_from_position(setup[1], setup[2], Vector3.UP)
	if _cam.is_inside_tree():
		_place_col_labels(kind)
	_frames = 0


func _place_col_labels(kind: String) -> void:
	for l in _col_labels:
		l.queue_free()
	_col_labels.clear()
	var items := _items(kind)
	var head_y := 2.0 if _is_figure(kind) else 0.42
	for i in items.size():
		var l := _label(Vector2.ZERO, 24 if _is_figure(kind) else 20, Color(0.97, 0.97, 0.97))
		l.text = items[i][1]
		var head := _slot(kind, i, items.size()) + Vector3(0, head_y, 0)
		l.position = _cam.unproject_position(head) - Vector2(45, 0)
		_col_labels.append(l)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		_place_col_labels(JOBS[_job][0])  # the camera is in the tree now
	if _frames < SETTLE_FRAMES:
		return
	var job: Array = JOBS[_job]
	var crop: Array = SETUPS[job[1]][4]
	var shot := _vp.get_texture().get_image()
	shot.convert(Image.FORMAT_RGBA8)
	var y0 := mini(int(crop[0]), shot.get_height() - 1)
	var h := mini(int(crop[1]), shot.get_height() - y0)
	var look: String = job[2][_look]
	var row_path := ROW_DIR + String(job[3]).get_basename() + "_" + look + ".png"
	shot.get_region(Rect2i(0, y0, shot.get_width(), h)).save_png(row_path)
	_rows.append({"image": ProjectSettings.globalize_path(row_path), "band": BANDS[look]})
	_look += 1
	if _look < (job[2] as Array).size():
		_start_capture()
		return
	(
		_sheets
		. append(
			{
				"out": ProjectSettings.globalize_path("res://.dev/" + String(job[3])),
				"width": WIDTH,
				"title": job[4],
				"rows": _rows.duplicate(),
			}
		)
	)
	_rows.clear()
	_look = 0
	_job += 1
	if _job < JOBS.size():
		_start_capture()
		return
	quit(_compose())


## Hand the raw rows to tools/cloth_sheets.py, which draws the title strips and the
## BEFORE / AFTER bands and saves the sheets. Returns the exit code for quit().
func _compose() -> int:
	var manifest := ROW_DIR + "manifest.json"
	var f := FileAccess.open(manifest, FileAccess.WRITE)
	f.store_string(JSON.stringify({"sheets": _sheets}, "\t"))
	f.close()
	var out: Array = []
	var args := [ProjectSettings.globalize_path(COMPOSER), ProjectSettings.globalize_path(manifest)]
	var code := OS.execute("python", args, out, true)
	for line: String in out:
		print(line)
	print("shot_cloth_photo: done (composer exit %d)." % code)
	return code
