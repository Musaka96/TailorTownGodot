extends SceneTree

## Lighting / post-processing study for Cloth Look v3: the same three cloths (navy
## worsted pinstripe, brown tweed, mid-grey flannel) on the real garment meshes and on
## material_roll bolts, under eight light + post setups. Render study only: nothing in
## the game is changed; the game's own values are read from its scenes.
##   light_<variant>.png   title + settings line, then figures close / rolls close /
##                         figures from the gameplay camera / its centre zoomed 4x
##   light_ALL.png         every variant's figures-close row, stacked with name bands
##   light_ALL_rolls.png   the same for the rolls rows
##   light_ALL_game.png    the same for the 4x gameplay-camera zooms
## Raw rows go to .dev/light_rows/; tools/cloth_sheets.py (PIL) lays out the sheets.
## NOT headless (needs a GPU), and it must quit:
##   timeout 300 godot --path . --script res://tools/shot_cloth_light.gd

const GLB := "res://assets/characters/CHARTGEN1.glb"
# Loaded lazily: their script chains reach autoloads a --script SceneTree has not
# registered yet when this script's constants compile.
const ROLL_SCENE := "res://entities/items/material_roll.tscn"
const BOX_SCRIPT := "res://entities/fx/delivery_box.gd"
# Where the game's light, environment and camera come from (the grandpa shop is the
# live map; Hemming's shop_room.tscn has the same environment and light).
const ROOM_SCENE := "res://scenes/world/grandpa/grandpa_shop_room.tscn"
const CAM_SCENE := "res://scenes/camera/camera_rig.tscn"
const OUTLINE_PROFILE := "res://data/outline.tres"
const OUTLINE_SHADER := "res://materials/outline_postfx.gdshader"
const OUTLINE_PARAMS: Array[String] = [
	"outline_color",
	"thickness",
	"opacity",
	"depth_threshold",
	"edge_softness",
	"grazing_guard",
	"crease_strength",
	"crease_threshold",
	"fade_start",
	"fade_end",
]
const ROW_DIR := "res://.dev/light_rows/"
const COMPOSER := "res://tools/cloth_sheets.py"
const WIDTH := 1600
const HEIGHT := 900
const FIG_SPACING := 0.85
const FIG_UV_SCALE := 6.0  # CharacterRig.CLOTH_UV_SCALE, as shot_cloth_photo uses
## The glb is in a T-pose: the upper arms swing down this far so three fit side by side.
const ARM_DROP := 72.0
const ROLL_XS: Array[float] = [-0.9, -0.45, 0.0]
const BOX_XS: Array[float] = [0.8, 1.1]
const NAVY := Color("1b2a4a")
const BROWN := Color("5a4633")
const MID_GREY := Color("6e7279")
const CHALK := Color("f0efe6")
const FLOOR := Color(0.42, 0.4, 0.38)
const SHIRT := Color(0.92, 0.92, 0.9)
# CLOSE camera: [look-at, distance, pitch down (deg), vertical fov] per subject.
const CLOSE := {
	"figures": [Vector3(0, 0.66, 0), 3.05, 20.0, 30.0],
	"rolls": [Vector3(0.3, 0.1, 0.05), 3.2, 20.0, 30.0],
}
# The lit variants' key light (light comes from camera-left, turned this far toward
# the camera), fill and ambient.
const KEY_AZIMUTH := 35.0
const KEY_COLOR := Color(1.0, 0.97, 0.92)
const FILL_COLOR := Color(0.85, 0.9, 1.0)
const AMBIENT := Color(0.62, 0.66, 0.74)
const SHADOW_DISTANCE := 50.0  # the game light's directional_shadow_max_distance
const VARIANTS: Array[String] = [
	"game_live",
	"game_clean",
	"window",
	"window_agx",
	"studio",
	"window_ssao",
	"raking",
	"soft_sky",
]
const SUMMARY := {
	"window":
	(
		"Key 45° up, 35° off camera-left, e1.2 (1.0, 0.97, 0.92), shadow blur 2.0;"
		+ " ambient colour (0.62, 0.66, 0.74) e0.45; game tonemap; no SSAO / glow / fog"
	),
	"window_agx": "window + AgX tonemap, exposure 1.15",
	"studio":
	(
		"window + cool fill from camera-right (e0.35, 30° up, no shadow)"
		+ " + back light from behind, 60° up (e0.6, no shadow)"
	),
	"window_ssao": "window + SSAO (radius 0.5, intensity 2.0) + SSIL (intensity 1.5)",
	"raking": "window with the key down at 18° elevation, same side",
	"soft_sky":
	(
		"Ambient from a procedural sky (light blue top, warm grey ground), sky contribution 1.0;"
		+ " key e0.9, shadow blur 3.0; AgX exposure 1.1"
	),
}
const SHORT := {
	"game_live": "game light + PostFX, as played",
	"game_clean": "game light, PostFX off",
	"window": "key 45°, ambient 0.45, game tonemap",
	"window_agx": "window + AgX 1.15",
	"studio": "window + cool fill + back light",
	"window_ssao": "window + SSAO 2.0 + SSIL 1.5",
	"raking": "key at 18°",
	"soft_sky": "sky ambient, key 0.9, AgX 1.1",
}
const TONEMAPS: Array[String] = ["Linear", "Reinhard", "Filmic", "ACES", "AgX"]
# [row id, subject, camera, caption]
const SHOTS := [
	[
		"figures_close",
		"figures",
		"close",
		"FIGURES, CLOSE    navy worsted pinstripe  |  brown tweed  |  mid-grey flannel",
	],
	[
		"rolls_close",
		"rolls",
		"close",
		"ROLLS, CLOSE    pinstripe  |  tweed  |  flannel  |  delivery box: pinstripe + flannel",
	],
	[
		"figures_game",
		"figures",
		"game",
		"FIGURES, GAMEPLAY CAMERA    pinstripe  |  tweed  |  flannel",
	],
]
const ZOOM := 4
const ZOOM_CAPTION := "FIGURES, GAMEPLAY CAMERA, CENTRE 4x    same render, nearest-neighbour zoom"
const SETTLE_FRAMES := 14

var _vp: SubViewport
var _world: Node3D
var _we: WorldEnvironment
var _cam: Camera3D
var _lights: Node3D
var _figures: Node3D
var _rolls: Node3D
var _postfx: CanvasLayer
var _outline: MeshInstance3D
var _game_env: Environment
var _game_light := {}
var _game_cam := {}
var _pfx_profile: Resource
var _notes: Array[String] = []
var _summaries := {}
var _rows := {}
var _built := false
var _variant := 0
var _shot := 0
var _frames := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROW_DIR))
	_vp = SubViewport.new()
	_vp.size = Vector2i(WIDTH, HEIGHT)
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)
	_read_game()
	_build_stage()
	_build_figures()
	process_frame.connect(_on_frame)


# --- The game's own values -----------------------------------------------------


## The shop's WorldEnvironment + key DirectionalLight3D and the camera rig's camera,
## read from the packed scenes (nothing is instanced).
func _read_game() -> void:
	var env_props := _scene_props(ROOM_SCENE, "WorldEnvironment")
	_game_env = (env_props["environment"] as Environment).duplicate()
	_game_light = _scene_props(ROOM_SCENE, "DirectionalLight3D")
	_game_cam = _scene_props(CAM_SCENE, "Camera3D")


func _scene_props(path: String, node_name: String) -> Dictionary:
	var state := (load(path) as PackedScene).get_state()
	for i in state.get_node_count():
		if String(state.get_node_name(i)) != node_name:
			continue
		var out := {}
		for p in state.get_node_property_count(i):
			out[String(state.get_node_property_name(i, p))] = state.get_node_property_value(i, p)
		return out
	push_error("shot_cloth_light: no %s in %s" % [node_name, path])
	return {}


# --- Stage + subjects ------------------------------------------------------------


func _build_stage() -> void:
	_we = WorldEnvironment.new()
	_world.add_child(_we)
	_lights = Node3D.new()
	_world.add_child(_lights)
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor_mesh.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = FLOOR
	fm.roughness = 1.0
	floor_mesh.material_override = fm
	_world.add_child(floor_mesh)
	_cam = Camera3D.new()
	_world.add_child(_cam)
	_cam.make_current()
	_outline = _make_outline()
	_cam.add_child(_outline)


## The Outline autoload's screen-space pass, rebuilt on this camera (the autoload rides
## the root viewport's camera, which a SubViewport never is).
func _make_outline() -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = load(OUTLINE_SHADER)
	var profile: Resource = load(OUTLINE_PROFILE)
	for param in OUTLINE_PARAMS:
		mat.set_shader_parameter(param, profile.get(param))
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat
	mi.extra_cull_margin = 16384.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	if not bool(profile.get("enabled")):
		_notes.append("Outline profile is disabled in the game, so no outline either.")
		mi.set_meta("off", true)
	return mi


func _cloths() -> Array[MaterialType]:
	return [
		_cloth(0, 1, NAVY),  # worsted, pinstripe
		_cloth(2, 0, BROWN),  # tweed, solid
		_cloth(1, 0, MID_GREY),  # flannel, solid
	]


func _cloth(fabric: int, pattern: int, cloth: Color) -> MaterialType:
	var mat := MaterialType.new()
	mat.fabric = fabric as Enums.Fabric
	mat.pattern = pattern as Enums.Pattern
	mat.cloth_color = cloth
	mat.pattern_color = CHALK
	mat.roll_length_m = 20.0
	mat.display_name = "Study cloth"
	return mat


func _build_figures() -> void:
	_figures = Node3D.new()
	_world.add_child(_figures)
	var cloths := _cloths()
	for i in cloths.size():
		var fig := (load(GLB) as PackedScene).instantiate() as Node3D
		fig.position = Vector3((i - 1) * FIG_SPACING, 0, 0)
		_figures.add_child(fig)
		_dress(fig, ClothMaterial.build(cloths[i], FIG_UV_SCALE, true))


## Garments only (jacket, buttons, trousers, flat white shirt), arms lowered.
func _dress(fig: Node3D, cloth: ShaderMaterial) -> void:
	var skel := fig.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for child in skel.get_children():
		var mi := child as MeshInstance3D
		if mi == null:
			continue
		match String(mi.name):
			"jacket", "legs":
				mi.material_override = cloth
			"shirt":
				var flat := StandardMaterial3D.new()
				flat.albedo_color = SHIRT
				flat.roughness = 1.0
				mi.material_override = flat
			"buttons":
				pass
			_:
				mi.visible = false


## Lower every figure's arms. Only after the first frame: a pose set before then is
## lost when the skeleton finishes setting up.
func _lower_arms() -> void:
	for skel: Skeleton3D in _figures.find_children("*", "Skeleton3D", true, false):
		_drop_arm(skel, "upperarm.l", -ARM_DROP)
		_drop_arm(skel, "upperarm.r", ARM_DROP)


func _drop_arm(skel: Skeleton3D, bone: String, degrees: float) -> void:
	var i := skel.find_bone(bone)
	var g := skel.get_bone_global_pose(i)
	var turn := Basis(Vector3.BACK, deg_to_rad(degrees))
	skel.set_bone_global_pose(i, Transform3D(turn * g.basis, g.origin))


## Three bolts in a row, and two more in a delivery box beside them (built once the
## autoloads are up: the box's script reaches EventBus / Sfx).
func _build_rolls() -> void:
	_rolls = Node3D.new()
	_world.add_child(_rolls)
	var cloths := _cloths()
	for i in cloths.size():
		_add_roll(cloths[i], ROLL_XS[i])
	var boxed: Array = [_add_roll(cloths[0], BOX_XS[0]), _add_roll(cloths[2], BOX_XS[1])]
	var script: Script = load(BOX_SCRIPT)
	var box: Node3D = null
	if script != null:
		box = script.call("wrap_all", boxed)
	if box == null:
		_notes.append("Delivery box could not be built: the two boxed rolls lie bare.")
		return
	# Jump its pop-in / unpack show to the end: open, sides flat, bolts lying on it.
	var tween: Tween = box.get("_tween")
	if tween != null:
		tween.custom_step(10.0)
	for p in _rolls.find_children("*", "CPUParticles3D", true, false):
		p.free()


func _add_roll(mat: MaterialType, x: float) -> Node3D:
	var roll := (load(ROLL_SCENE) as PackedScene).instantiate() as Node3D
	roll.set("material", mat)
	_rolls.add_child(roll)
	roll.position = Vector3(x, roll.call("radius"), 0)
	return roll


## The PostFX autoload's filter, laid over this SubViewport with the very same
## ShaderMaterial (the autoload pushes the live profile into it every frame).
func _build_postfx() -> void:
	var pfx := root.get_node_or_null("PostFX")
	var mat: ShaderMaterial = pfx.get("_mat") if pfx != null else null
	if mat == null:
		_notes.append("PostFX autoload not found: game_live has no post filter.")
		return
	_pfx_profile = pfx.get("profile")
	_postfx = CanvasLayer.new()
	_postfx.layer = 100
	_vp.add_child(_postfx)
	var rect := ColorRect.new()
	rect.position = Vector2.ZERO
	rect.size = Vector2(WIDTH, HEIGHT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = mat
	_postfx.add_child(rect)
	_postfx.visible = false


# --- Variants ------------------------------------------------------------------


func _apply_variant(name: String) -> void:
	for c in _lights.get_children():
		c.free()
	var game := name.begins_with("game_")
	if _postfx != null:
		_postfx.visible = name == "game_live"
	_outline.visible = game and not _outline.has_meta("off")
	_cam.attributes = _game_cam.get("attributes") if game else null
	if game:
		_we.environment = _game_env.duplicate()
		_game_sun()
		_summaries[name] = _game_summary(name == "game_live")
		return
	var env := _window_env()
	_we.environment = env
	_summaries[name] = SUMMARY[name]
	match name:
		"window", "window_agx", "window_ssao":
			_key(45.0, 1.2, 2.0)
			if name == "window_agx":
				env.tonemap_mode = Environment.TONE_MAPPER_AGX
				env.tonemap_exposure = 1.15
			elif name == "window_ssao":
				env.ssao_enabled = true
				env.ssao_radius = 0.5
				env.ssao_intensity = 2.0
				env.ssil_enabled = true
				env.ssil_intensity = 1.5
		"studio":
			_key(45.0, 1.2, 2.0)
			_add_light(_source(30.0, KEY_AZIMUTH, true), 0.35, FILL_COLOR, false, 0.0)
			_add_light(Vector3(0, sin(deg_to_rad(60.0)), -cos(deg_to_rad(60.0))), 0.6, KEY_COLOR)
		"raking":
			_key(18.0, 1.2, 2.0)
		"soft_sky":
			_key(45.0, 0.9, 3.0)
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			env.ambient_light_sky_contribution = 1.0
			env.ambient_light_energy = 1.0
			env.sky = _sky()
			env.tonemap_mode = Environment.TONE_MAPPER_AGX
			env.tonemap_exposure = 1.1


## The game's key light as authored in the shop scene, plus any lighting override the
## active PostFX profile carries (PostFxLighting does the same in play).
func _game_sun() -> void:
	var sun := DirectionalLight3D.new()
	for prop: String in _game_light:
		sun.set(prop, _game_light[prop])
	_lights.add_child(sun)
	if _pfx_profile != null and bool(_pfx_profile.get("override_lighting")):
		var pl := PostFxLighting.new()
		var env_values: Dictionary = pl.call("_env_values", _pfx_profile)
		var sun_values: Dictionary = pl.call("_sun_values", _pfx_profile)
		for prop: StringName in env_values:
			_we.environment.set(prop, env_values[prop])
		for prop: StringName in sun_values:
			sun.set(prop, sun_values[prop])
		_notes.append("PostFX profile overrides lighting: applied to the game variants.")


## Variants 3-8 start from this: the game's tonemap and background, ambient from a flat
## colour, and none of the shop's SSAO / glow / fog / colour adjustment.
func _window_env() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = _game_env.background_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT
	env.ambient_light_energy = 0.45
	env.tonemap_mode = _game_env.tonemap_mode
	env.tonemap_exposure = _game_env.tonemap_exposure
	env.tonemap_white = _game_env.tonemap_white
	return env


func _sky() -> Sky:
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.55, 0.72, 0.92)
	mat.sky_horizon_color = Color(0.78, 0.84, 0.9)
	mat.ground_horizon_color = Color(0.62, 0.59, 0.55)
	mat.ground_bottom_color = Color(0.45, 0.42, 0.39)
	var sky := Sky.new()
	sky.sky_material = mat
	return sky


func _key(elevation: float, energy: float, blur: float) -> void:
	_add_light(_source(elevation, KEY_AZIMUTH, false), energy, KEY_COLOR, true, blur)


## Unit vector toward a light `elevation` degrees up, coming from camera-left (or
## camera-right when `mirror`) turned `azimuth` degrees toward the camera. Both
## cameras look down -Z, so camera-left is -X and the camera side is +Z.
func _source(elevation: float, azimuth: float, mirror: bool) -> Vector3:
	var e := deg_to_rad(elevation)
	var a := deg_to_rad(azimuth)
	var side := 1.0 if mirror else -1.0
	return Vector3(side * cos(a) * cos(e), sin(e), sin(a) * cos(e))


func _add_light(
	toward: Vector3, energy: float, color: Color, shadows := false, blur := 1.0
) -> void:
	var light := DirectionalLight3D.new()
	light.basis = Basis.looking_at(-toward, Vector3.UP)
	light.light_energy = energy
	light.light_color = color
	light.shadow_enabled = shadows
	light.shadow_blur = blur
	light.directional_shadow_max_distance = SHADOW_DISTANCE
	_lights.add_child(light)


func _game_summary(with_postfx: bool) -> String:
	var e := _game_env
	var dir: Vector3 = -(_game_light.get("transform", Transform3D()) as Transform3D).basis.z
	var parts: PackedStringArray = [
		(
			"Shop env: %s exp %.2f, ambient colour e%.2f, SSAO %.1f, glow %.2f, fog %.3f,"
			% [
				TONEMAPS[e.tonemap_mode],
				e.tonemap_exposure,
				e.ambient_light_energy,
				e.ssao_intensity,
				e.glow_intensity,
				e.fog_density,
			]
		),
		(
			"contrast %.2f sat %.2f; sun %.0f° up from the camera side, e%.2f, blur %.1f;"
			% [
				e.adjustment_contrast,
				e.adjustment_saturation,
				rad_to_deg(asin(-dir.y)),
				float(_game_light.get("light_energy", 1.0)),
				float(_game_light.get("shadow_blur", 1.0)),
			]
		),
		"DOF far 12 m; outline;",
	]
	if with_postfx and _pfx_profile != null:
		var p := _pfx_profile
		(
			parts
			. append(
				(
					"PostFX: grain %.3f, scanlines %.3f, CA %.3f, barrel %.3f"
					% [
						p.get("film_strength"),
						p.get("scanline_strength"),
						p.get("chromatic_aberration"),
						p.get("barrel_distortion"),
					]
				)
			)
		)
	else:
		parts.append("PostFX off")
	return " ".join(parts)


# --- Cameras + capture -----------------------------------------------------------


func _place_camera(subject: String, which: String) -> void:
	if which == "game":
		# The rig sits on the player (here: the middle figure) with its camera at the
		# authored home offset, pitch and FOV.
		_cam.transform = _game_cam.get("transform", Transform3D())
		_cam.fov = float(_game_cam.get("fov", 75.0))
		return
	var c: Array = CLOSE[subject]
	var target: Vector3 = c[0]
	var pitch := deg_to_rad(float(c[2]))
	var eye := target + Vector3(0, sin(pitch), cos(pitch)) * float(c[1])
	_cam.fov = float(c[3])
	_cam.look_at_from_position(eye, target, Vector3.UP)


func _start_shot() -> void:
	if _shot == 0:
		_apply_variant(VARIANTS[_variant])
	var shot: Array = SHOTS[_shot]
	_figures.visible = shot[1] == "figures"
	_rolls.visible = shot[1] == "rolls"
	_place_camera(shot[1], shot[2])
	_frames = 0


func _on_frame() -> void:
	_frames += 1
	if not _built:
		# Autoloads have run _ready by now.
		if _frames < 2:
			return
		_built = true
		_lower_arms()
		_build_rolls()
		_build_postfx()
		_start_shot()
		return
	if _frames < SETTLE_FRAMES:
		return
	var name := VARIANTS[_variant]
	var row_id: String = SHOTS[_shot][0]
	var path := ROW_DIR + name + "_" + row_id + ".png"
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(path)
	_rows[name + "/" + row_id] = ProjectSettings.globalize_path(path)
	if row_id == "figures_game":
		_save_zoom(img, name)
	_shot += 1
	if _shot >= SHOTS.size():
		_shot = 0
		_variant += 1
		if _variant >= VARIANTS.size():
			quit(_compose())
			return
	_start_shot()


## At the real gameplay FOV the figures are small, so the game row also gets the patch
## around them blown up ZOOM x with nearest-neighbour: the very pixels the player gets.
func _save_zoom(img: Image, name: String) -> void:
	var size := Vector2i(WIDTH / ZOOM, HEIGHT / ZOOM)
	var centre := Vector2i(_cam.unproject_position(Vector3(0, 0.6, 0)))
	var corner := (centre - size / 2).clamp(Vector2i.ZERO, Vector2i(WIDTH, HEIGHT) - size)
	var patch := img.get_region(Rect2i(corner, size))
	patch.resize(WIDTH, HEIGHT, Image.INTERPOLATE_NEAREST)
	var path := ROW_DIR + name + "_figures_game_zoom.png"
	patch.save_png(path)
	_rows[name + "/figures_game_zoom"] = ProjectSettings.globalize_path(path)


# --- Sheets ----------------------------------------------------------------------


func _compose() -> int:
	var sheets: Array[Dictionary] = []
	for name in VARIANTS:
		var rows: Array[Dictionary] = []
		for shot: Array in SHOTS:
			rows.append({"image": _rows[name + "/" + String(shot[0])], "caption": shot[3]})
		rows.append({"image": _rows[name + "/figures_game_zoom"], "caption": ZOOM_CAPTION})
		(
			sheets
			. append(
				{
					"out": _dev("light_%s.png" % name),
					"width": WIDTH,
					"title": name,
					"subtitle": _summaries[name],
					"rows": rows,
				}
			)
		)
	sheets.append(_contact("light_ALL.png", "ALL VARIANTS, FIGURES CLOSE", "figures_close"))
	sheets.append(_contact("light_ALL_rolls.png", "ALL VARIANTS, ROLLS CLOSE", "rolls_close"))
	sheets.append(
		_contact("light_ALL_game.png", "ALL VARIANTS, GAMEPLAY CAMERA 4x", "figures_game_zoom")
	)
	var manifest := ROW_DIR + "manifest.json"
	var f := FileAccess.open(manifest, FileAccess.WRITE)
	f.store_string(JSON.stringify({"sheets": sheets}, "\t"))
	f.close()
	var out: Array = []
	var args := [ProjectSettings.globalize_path(COMPOSER), ProjectSettings.globalize_path(manifest)]
	var code := OS.execute("python", args, out, true)
	for line: String in out:
		print(line)
	for note in _notes:
		print("NOTE: ", note)
	print("shot_cloth_light: done (composer exit %d)." % code)
	return code


func _contact(file: String, title: String, row_id: String) -> Dictionary:
	var rows: Array[Dictionary] = []
	for name in VARIANTS:
		(
			rows
			. append(
				{
					"image": _rows[name + "/" + row_id],
					"band": {"style": "name", "lines": [name, SHORT[name]]},
				}
			)
		)
	return {"out": _dev(file), "width": WIDTH, "title": title, "rows": rows}


func _dev(file: String) -> String:
	return ProjectSettings.globalize_path("res://.dev/" + file)
