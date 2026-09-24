extends Node3D

## Cloth refs — dev experiment, NOT part of the game. Rebuilds a scanned 3x5 cloth-swatch
## reference sheet in-engine with materials/cloth_experiment.gdshader, so a screenshot
## can be laid over the scan. Grain/normal tiles, mean colours and the sheet's grid
## layout come from tools/cloth_refs/make_grain.py (assets/dev/cloth_refs/).
##
## Command-line (after tools/screenshot.gd's scene/out/frames args):
##   sheet=suitings|shirtings   which reference sheet (default suitings)
##   mode=direct|game           direct = each swatch's own photo grain; game = suitings
##                              6/7/8/10 use the navy worsted grain under the game's
##                              procedural pattern tiles (default direct)
##   flat=1                     plain lambert: sheen, wrap and aniso all 0
##   energy=E                   ambient and sun energy (default ENERGY, calibrated)
##
## The frame is the sheet's shape (1.75:1) centred in the viewport; compare images crop
## the render to that before scaling it next to the scan.

const SHADER := preload("res://materials/cloth_experiment.gdshader")
const REFS_PATH := "res://assets/dev/cloth_refs/refs.json"
const TEX_DIR := "res://assets/dev/cloth_refs/"
const PATTERN_DIR := "res://assets/textures/patterns/"
const COLS := 5
const ROWS := 3
const GRAIN_MEAN := 0.25  # stored mean of the linear grain PNGs (make_grain.py)
# Ambient and sun energy, both. Calibrated so the flannel (suitings_2) renders at its
# scan's mean luma (tools/cloth_refs/compare.py measure): 1.001 at 0.546.
const ENERGY := 0.546
const LIGHT_TILT := 25.0  # degrees off the camera axis
# mode=game swaps on the suitings sheet: photo grain of the navy worsted (suitings_1)
# under a game pattern tile. "color_from" takes the mean colour of that swatch.
# "scale" = motifs across the scan square / motifs across the game tile
# (tools/cloth_refs/tile_period.py): pinstripe 5.2/8, herringbone 8.6/8 columns,
# houndstooth 11.6/4, windowpane 2.33/2.
const GAME_GRAIN := 1
const GAME_SWAPS := {
	6: {"pattern": "pinstripe", "color_from": 1, "pattern_color": "#f0efe6", "scale": 0.65},
	7: {"pattern": "herringbone", "color_from": 7, "pattern_color": "#9a9ea6", "scale": 1.07},
	8: {"pattern": "houndstooth", "color": "#26241f", "pattern_color": "#d8cdb3", "scale": 2.9},
	10: {"pattern": "windowpane", "color_from": 10, "pattern_color": "#b8893a", "scale": 1.17},
}
# Per-swatch lighting overrides on the suitings sheet.
const SUITINGS_TUNING := {
	2: {"sheen": 0.9, "sheen_roughness": 0.9},  # flannel
	4: {"aniso": 0.35, "aniso_shine": 40.0},  # mohair
}
const BASE_PARAMS := {
	"grain_mean": GRAIN_MEAN,
	"grain_scale": 1.0,
	"pattern_scale": 1.0,
	"grain_strength": 1.0,
	"grain_contrast": 1.0,
	"normal_depth": 1.0,
	"pattern_intensity": 1.0,
	"wrap": 0.35,
	"sheen": 0.6,
	"sheen_roughness": 0.75,
	"sheen_tint": 0.5,
	"aniso": 0.0,
}
const FLAT_PARAMS := {"sheen": 0.0, "wrap": 0.0, "aniso": 0.0}
# Used when refs.json has no layout for the sheet.
const DEFAULT_LAYOUT := {
	"cell_aspect": 1.05,
	"gap": 0.015,
	"sheet_aspect": 1.75,
	"fill_h": 0.986,
	"offset_x": 0.0,
	"offset_y": 0.0,
}

var _sheet := "suitings"
var _mode := "direct"
var _flat := false
var _energy := ENERGY
var _layout: Dictionary = DEFAULT_LAYOUT
# Game autoload state switched off while this scene runs, put back in _exit_tree().
var _saved_fx: Dictionary = {}  # autoload name -> its original profile
var _saved_ui_visible := true
var _saved_world_scale := 1.0


func _ready() -> void:
	_isolate()
	_read_args()
	var colours: Dictionary = _load_refs()
	if colours.is_empty():
		push_error("cloth_refs: no colours for sheet '%s' in %s" % [_sheet, REFS_PATH])
		return
	if _mode == "game" and _sheet != "suitings":
		push_warning("cloth_refs: mode=game only swaps suitings; showing direct")
	_build_environment()
	_build_camera()
	_build_light()
	for n: int in range(1, COLS * ROWS + 1):
		_build_swatch(n, colours)


func _exit_tree() -> void:
	var root: Window = get_tree().root
	for autoload: String in _saved_fx:
		var fx: Node = root.get_node_or_null(autoload)
		if fx != null:
			fx.call("set_profile", _saved_fx[autoload])
	var ui: CanvasLayer = root.get_node_or_null("UI") as CanvasLayer
	if ui != null:
		ui.visible = _saved_ui_visible
	var world_scale: Node = root.get_node_or_null("WorldScale")
	if world_scale != null:
		world_scale.set("factor", _saved_world_scale)


## Keep the game's autoloads out of the picture, in memory only (nothing is saved): the
## retro PostFX grade and the Outline pass get a disabled copy of their profile, the HUD
## is hidden, and WorldScale's factor goes to 1 so it leaves the swatch quads alone.
## WorldScale.set_factor() is not used because it writes the dial to the user config.
func _isolate() -> void:
	var root: Window = get_tree().root
	for autoload: String in ["PostFX", "Outline"]:
		var fx: Node = root.get_node_or_null(autoload)
		if fx == null:
			continue
		var profile: Resource = fx.get("profile")
		if profile == null:
			continue
		_saved_fx[autoload] = profile
		var off: Resource = profile.duplicate()
		off.set("enabled", false)
		fx.call("set_profile", off)
	var ui: CanvasLayer = root.get_node_or_null("UI") as CanvasLayer
	if ui != null:
		_saved_ui_visible = ui.visible
		ui.visible = false
	var world_scale: Node = root.get_node_or_null("WorldScale")
	if world_scale != null:
		_saved_world_scale = float(world_scale.get("factor"))
		world_scale.set("factor", 1.0)


func _read_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=", false, 1)
		if kv.size() != 2:
			continue
		if kv[0] == "sheet" and kv[1] in ["suitings", "shirtings"]:
			_sheet = kv[1]
		elif kv[0] == "mode" and kv[1] in ["direct", "game"]:
			_mode = kv[1]
		elif kv[0] == "flat":
			_flat = kv[1] == "1"
		elif kv[0] == "energy" and kv[1].is_valid_float():
			_energy = kv[1].to_float()


## Reads the sheet's layout into _layout and returns swatch number -> mean colour (sRGB).
func _load_refs() -> Dictionary:
	var out: Dictionary = {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(REFS_PATH))
	if not parsed is Dictionary:
		return out
	var data: Dictionary = parsed
	var layouts: Dictionary = data.get("layout", {})
	if layouts.has(_sheet):
		_layout = layouts[_sheet]
	for entry: Dictionary in data.get(_sheet, []):
		out[int(entry["n"])] = Color.html(String(entry["color"]))
	return out


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 0.95)
	env.ambient_light_energy = _energy
	env.glow_enabled = false
	env.ssao_enabled = false
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)


## Cell size in world units: 1 tall, cell_aspect wide.
func _cell() -> Vector2:
	return Vector2(float(_layout["cell_aspect"]), 1.0)


## Step from one cell to the next: the cell plus the lid gap (a fraction of the height).
func _pitch() -> Vector2:
	var gap: float = float(_layout["gap"])
	return _cell() + Vector2(gap, gap)


func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	var view: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = view.x / maxf(view.y, 1.0)
	var sheet_aspect: float = float(_layout["sheet_aspect"])
	var grid_h: float = ROWS * _pitch().y - float(_layout["gap"])
	# Height of a sheet-shaped frame, centred in the viewport; if the viewport is narrower
	# than the sheet, grow the view so the whole frame still fits.
	var frame_h: float = grid_h / float(_layout["fill_h"])
	cam.size = frame_h * maxf(1.0, sheet_aspect / aspect)
	cam.near = 0.1
	cam.far = 50.0
	# The scan's grid sits a little off the sheet centre; shift the view to match.
	var shift := Vector3(float(_layout["offset_x"]), 0.0, float(_layout["offset_y"])) * frame_h
	# Straight down; screen up is world -Z, screen right is world +X.
	cam.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0.0, 10.0, 0.0) - shift)
	add_child(cam)
	cam.make_current()


func _build_light() -> void:
	var light := DirectionalLight3D.new()
	light.light_energy = _energy
	light.shadow_enabled = false
	# From the image's top-left (-X, -Z) toward its bottom-right, tilted off vertical.
	var tilt: float = deg_to_rad(LIGHT_TILT)
	var across := Vector3(1.0, 0.0, 1.0).normalized()
	var dir: Vector3 = (Vector3.DOWN * cos(tilt) + across * sin(tilt)).normalized()
	light.transform = Transform3D(Basis.looking_at(dir, Vector3.FORWARD), Vector3.ZERO)
	add_child(light)


func _build_swatch(n: int, colours: Dictionary) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	for key: String in BASE_PARAMS:
		mat.set_shader_parameter(key, BASE_PARAMS[key])
	var grain_n: int = n
	var colour: Color = colours.get(n, Color.GRAY)
	var pattern := "solid"
	var pattern_colour := Color(0.9, 0.9, 0.9)
	if _mode == "game" and _sheet == "suitings" and GAME_SWAPS.has(n):
		var swap: Dictionary = GAME_SWAPS[n]
		grain_n = GAME_GRAIN
		pattern = swap["pattern"]
		pattern_colour = Color.html(String(swap["pattern_color"]))
		if swap.has("color_from"):
			colour = colours.get(int(swap["color_from"]), colour)
		else:
			colour = Color.html(String(swap["color"]))
		mat.set_shader_parameter("pattern_scale", float(swap["scale"]))
	if _sheet == "suitings" and SUITINGS_TUNING.has(n):
		var tuning: Dictionary = SUITINGS_TUNING[n]
		for key: String in tuning:
			mat.set_shader_parameter(key, tuning[key])
	if _flat:
		for key: String in FLAT_PARAMS:
			mat.set_shader_parameter(key, FLAT_PARAMS[key])
	# The raw (unblended) pair: one tile = one swatch, so no repeat seam to hide.
	var stem := "%s%s_%d" % [TEX_DIR, _sheet, grain_n]
	mat.set_shader_parameter("grain_tex", load(stem + ".png"))
	mat.set_shader_parameter("grain_normal", load(stem + "_n.png"))
	mat.set_shader_parameter("pattern_tex", load(PATTERN_DIR + pattern + ".png"))
	mat.set_shader_parameter("cloth_color", colour)
	mat.set_shader_parameter("pattern_color", pattern_colour)

	var plane := PlaneMesh.new()  # faces +Y; UV (0,0) at the -X/-Z (top-left) corner
	plane.size = _cell()
	var swatch := MeshInstance3D.new()
	swatch.name = "Swatch%d" % n
	swatch.mesh = plane
	swatch.material_override = mat
	var col: int = (n - 1) % COLS
	var row: int = floori((n - 1) / float(COLS))
	var pitch: Vector2 = _pitch()
	swatch.position = Vector3(
		(col - (COLS - 1) * 0.5) * pitch.x, 0.0, (row - (ROWS - 1) * 0.5) * pitch.y
	)
	add_child(swatch)
