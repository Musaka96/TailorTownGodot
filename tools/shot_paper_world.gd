extends SceneTree

## LOOK TEST: the characters' paper on the world (assets/shaders/paper_world.gdshader).
## Boots the real shop (main.tscn), stands the player by the sewing machine in the sun,
## then renders the same corner with the world's materials as they are and swapped for
## paper. NOT headless:
##   godot --path . --script res://tools/shot_paper_world.gd -- [scout]
## scout: print where the stations stand and render an overview, nothing else.
## Writes to IMPORT/paper_world/ (git-ignored).

const OUT_DIR := "res://IMPORT/paper_world"
const SIZE := Vector2i(1600, 900)
const PAPER_SHADER := "res://assets/shaders/paper_world.gdshader"
const ROLL_SCENE := "res://entities/items/material_roll.tscn"
# shaders that are already the characters' paper, left alone
const KEEP_SHADERS := ["skin_face", "paper_skin", "face_element", "outline"]

# the variants: label, flatten (mip bias), tile (face units per metre), grain, rolls to
# paper, scan normal strength (the characters' PaperSurface has 1.0)
const VARIANTS := [
	["A  as it is", -1.0, 0.0, 0.0, false, 1.0],
	["B  paper, textures kept", 0.0, 5.0, 0.1, false, 1.0],
	["C  paper, textures softened, bolts paper too", 2.5, 5.0, 0.1, true, 1.0],
	["D  as C, paper 2x bigger", 2.5, 2.5, 0.12, true, 1.5],
	["E  as C, paper 4x bigger", 2.5, 1.25, 0.14, true, 2.0],
	["F  as C, paper 8x bigger, deep creases (for the game camera)", 2.5, 0.6, 0.18, true, 3.0],
]

const SUN_ROT := Vector3(-36.0, 25.0, 0.0)
const PLAYER_POS := Vector3(-2.55, 0.0, -3.85)
const PLAYER_YAW := 0.35
const CLOSE_EYE := Vector3(-0.2, 2.6, 0.4)
const CLOSE_AT := Vector3(-3.7, 0.95, -4.6)
# bolts: material, position, rotation (degrees)
const ROLLS := [
	["navy_worsted_pinstripe", Vector3(-4.75, 0.3, -4.55), Vector3(0, 0, 8)],
	["burgundy_mohair_birdseye", Vector3(-4.45, 0.3, -4.75), Vector3(0, 30, -6)],
	["tan_linen_solid", Vector3(-4.95, 0.3, -4.2), Vector3(4, 0, 0)],
	["grey_tweed_herringbone", Vector3(-3.3, 0.13, -3.3), Vector3(0, 70, 90)],
	["blue_worsted_glencheck", Vector3(-3.05, 0.13, -3.05), Vector3(0, 55, 90)],
]

var _main: Node
var _cam: Camera3D
var _player: Node3D
var _shader: Shader
var _meshes: Array = []  # [MeshInstance3D, surface, original material]
var _cache := {}


func _initialize() -> void:
	DisplayServer.window_set_size(SIZE)
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	current_scene = _main
	await _frames(3)
	var ui := root.get_node_or_null("UI")
	if ui != null:
		if ui.get("newspaper") != null:
			ui.newspaper.close()
		ui.visible = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_shader = load(PAPER_SHADER) as Shader
	_player = _main.find_child("Player", true, false) as Node3D
	if args.has("scout"):
		await _scout()
		quit(0)
		return
	await _stage()
	await _frames(40)
	if OS.get_cmdline_user_args().has("occluders"):
		var sun := _main.find_child("Sun", true, false) as DirectionalLight3D
		var to_sun := sun.global_basis.z.normalized()
		print("SUNDIR ", to_sun)
		for g: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
			if g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				print("SHONLY %s vis=%s" % [g.get_path(), g.is_visible_in_tree()])
		for pt in [Vector3(-3, 0.05, -3.2), Vector3(-5.8, 1.2, -3.0)]:
			for g: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
				if not g.is_visible_in_tree() or g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					continue
				var box: AABB = g.global_transform * g.get_aabb()
				if box.intersects_segment(pt + to_sun * 0.3, pt + to_sun * 300.0):
					print("OCC %s from %s box=%s" % [g.get_path(), pt, box])
		quit(0)
		return
	if OS.get_cmdline_user_args().has("over"):
		_cam.fov = 60.0
		_cam.look_at_from_position(Vector3(-1, 13, 3), Vector3(-2, 0, -3), Vector3.UP)
		await _frames(8)
		_save("over.png")
		quit(0)
		return
	if OS.get_cmdline_user_args().has("bisect"):
		_view(true)
		await _frames(6)
		var base := _lum()
		print("BASE ", base)
		var shop := _main.find_child("ShopRoom", true, false)
		var cands: Array = shop.get_children()
		var kit := _main.find_child("tailor_shop_v7", true, false)
		if kit != null:
			cands.append_array(kit.get_children())
		cands.append_array(_main.get_children())
		for c in cands:
			if not (c is Node3D) or not (c as Node3D).visible:
				continue
			(c as Node3D).visible = false
			await _frames(4)
			var l := _lum()
			(c as Node3D).visible = true
			if absf(l - base) > 0.01:
				print("BIS %s d=%.3f" % [c.get_path(), l - base])
		quit(0)
		return
	if OS.get_cmdline_user_args().has("sweep"):
		var sun := _main.find_child("Sun", true, false) as DirectionalLight3D
		_view(true)
		for r in [Vector3(-38, -55, 0), Vector3(-42, 70, 0), Vector3(-55, 30, 0), Vector3(-60, 120, 0), Vector3(-45, 160, 0), Vector3(-70, 0, 0)]:
			sun.rotation_degrees = r
			await _frames(6)
			_save("sweep_%d_%d.png" % [int(-r.x), int(r.y)])
		quit(0)
		return
	if OS.get_cmdline_user_args().has("noshadow"):
		(_main.find_child("Sun", true, false) as DirectionalLight3D).shadow_enabled = false
		_view(true)
		await _frames(8)
		_save("debug_noshadow.png")
		(_main.find_child("Sun", true, false) as DirectionalLight3D).light_energy = 0.0
		await _frames(8)
		_save("debug_nosun.png")
		quit(0)
		return
	for l: DirectionalLight3D in root.find_children("*", "DirectionalLight3D", true, false):
		print("LIGHT %s vis=%s e=%s sh=%s rot=%s" % [l.get_path(), l.is_visible_in_tree(), l.light_energy, l.shadow_enabled, l.global_rotation_degrees])
	for r in root.find_children("*Roof*", "", true, false):
		if r is Node3D:
			print("ROOF %s vis=%s" % [r.get_path(), (r as Node3D).is_visible_in_tree()])
	_collect()
	for v in VARIANTS.size():
		_apply(v)
		var tag := String(VARIANTS[v][0]).substr(0, 1).to_lower()
		for close in [true, false]:
			_view(close)
			await _frames(8)
			_save("%s_%s.png" % ["close" if close else "game", tag])
	quit(0)


func _scout() -> void:
	for n in ["SewingMachine", "Worktable", "Shelf", "Bookshelf", "ClothingRack", "Mirror",
			"Phone", "TrashCan", "Player", "Sun", "DirectionalLight3D"]:
		var node := _main.find_child(n, true, false) as Node3D
		if node != null:
			print("SCOUT %s pos=%s rot=%s" % [n, node.global_position, node.global_rotation_degrees])
	_cam = Camera3D.new()
	_main.add_child(_cam)
	_cam.look_at_from_position(Vector3(0, 16, 6), Vector3(0, 0, 0), Vector3.UP)
	_cam.make_current()
	await _frames(40)
	_save("scout.png")


# --- staging -------------------------------------------------------------------------------

## The back-left corner: bookshelf, sewing machine, bin; the player by the machine turned
## toward the camera; a few bolts leaning and lying about; the sun low from the front right
## so it rakes both walls.
func _stage() -> void:
	var day := root.get_node_or_null("DayNight")
	if day != null:
		day.set_process(false)
	var sun := _main.find_child("Sun", true, false) as DirectionalLight3D
	if sun != null:
		sun.visible = true
		sun.rotation_degrees = SUN_ROT
		sun.light_energy = 1.15
		sun.light_color = Color(1.0, 0.95, 0.86)
		sun.shadow_enabled = true
	# the neighbours' houses stand in the way of a low sun: they stop casting for the test
	var town := _main.find_child("Town", true, false)
	if town != null:
		for g: GeometryInstance3D in town.find_children("*", "GeometryInstance3D", true, false):
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_player.set_physics_process(false)
	_player.set_process(false)
	_player.global_position = PLAYER_POS
	var model := _player.get("_model") as Node3D
	if model != null:
		model.rotation.y = PLAYER_YAW
	var rolls := Node3D.new()
	rolls.name = "PaperTestRolls"
	_main.add_child(rolls)
	for r: Array in ROLLS:
		var roll := (load(ROLL_SCENE) as PackedScene).instantiate() as Node3D
		roll.set("material", load("res://data/materials/%s.tres" % r[0]))
		rolls.add_child(roll)
		roll.global_position = r[1]
		roll.rotation_degrees = r[2]
		for b in roll.find_children("*", "RigidBody3D", true, false):
			(b as RigidBody3D).freeze = true
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_main.add_child(_cam)
	_cam.make_current()


func _view(close: bool) -> void:
	if close:
		_cam.fov = 40.0
		_cam.look_at_from_position(CLOSE_EYE, CLOSE_AT, Vector3.UP)
	else:
		# the gameplay camera's angle (camera_rig.tscn, x WorldScale 0.85), on the player
		_cam.fov = 75.0
		var at := PLAYER_POS + Vector3(0, 0.9, 0)
		_cam.look_at_from_position(PLAYER_POS + Vector3(0, 6.271, 4.393) * 0.85, at, Vector3.UP)


# --- materials -----------------------------------------------------------------------------

## Every opaque surface outside the characters, with the material it shows now.
func _collect() -> void:
	_meshes.clear()
	for mi: MeshInstance3D in _main.find_children("*", "MeshInstance3D", true, false):
		if _in_character(mi) or mi.mesh == null or not mi.is_visible_in_tree():
			continue
		for s in mi.mesh.get_surface_count():
			_meshes.append([mi, s, mi.get_surface_override_material(s), mi.material_override])


func _in_character(n: Node) -> bool:
	while n != null:
		var sc: Script = n.get_script()
		if sc != null and sc.resource_path.contains("character_rig"):
			return true
		n = n.get_parent()
	return false


func _apply(v: int) -> void:
	var spec: Array = VARIANTS[v]
	for e: Array in _meshes:
		var mi: MeshInstance3D = e[0]
		var s: int = e[1]
		mi.material_override = e[3]
		mi.set_surface_override_material(s, e[2])
		if spec[1] < 0.0:
			continue
		var src := mi.get_active_material(s)
		var paper := _paper_for(src, spec, v)
		if paper != null:
			if mi.material_override != null:
				mi.material_override = null
			mi.set_surface_override_material(s, paper)


func _paper_for(src: Material, spec: Array, v: int) -> ShaderMaterial:
	if src == null:
		return null
	var key := "%d:%d" % [src.get_instance_id(), v]
	if _cache.has(key):
		return _cache[key]
	var out: ShaderMaterial = null
	var col := Color(-1, 0, 0)
	var tex: Texture2D = null
	var uv_scale := Vector3.ONE
	var uv_off := Vector3.ZERO
	var vcol := false
	if src is BaseMaterial3D:
		var b := src as BaseMaterial3D
		if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			pass
		else:
			col = b.albedo_color
			tex = b.albedo_texture
			uv_scale = b.uv1_scale
			uv_off = b.uv1_offset
			vcol = b.vertex_color_use_as_albedo
	elif src is ShaderMaterial:
		var sm := src as ShaderMaterial
		var path := sm.shader.resource_path if sm.shader != null else ""
		var keep := false
		for k in KEEP_SHADERS:
			keep = keep or path.contains(k)
		var cloth := path.contains("cloth") or path.contains("roll_end")
		if not keep and (not cloth or spec[4]):
			for p in ["cloth_color", "albedo_color", "albedo", "fill_color", "base_color", "color"]:
				var c: Variant = sm.get_shader_parameter(p)
				if c is Color:
					col = c
					break
			for p in ["albedo_texture", "texture_albedo", "albedo_tex"]:
				var t: Variant = sm.get_shader_parameter(p)
				if t is Texture2D:
					tex = t
					break
			var tl: Variant = sm.get_shader_parameter("albedo_tiling")
			if tl is Vector2:
				uv_scale = Vector3(tl.x, tl.y, 1.0)
	if col.r >= 0.0:
		out = ShaderMaterial.new()
		out.shader = _shader
		out.set_shader_parameter("albedo_color", col)
		if tex != null:
			out.set_shader_parameter("albedo_tex", tex)
		out.set_shader_parameter("uv1_scale", uv_scale)
		out.set_shader_parameter("uv1_offset", uv_off)
		out.set_shader_parameter("use_vertex_color", vcol)
		out.set_shader_parameter("flatten", spec[1])
		out.set_shader_parameter("tile", spec[2])
		out.set_shader_parameter("grain", spec[3])
		out.set_shader_parameter("seed", float(_cache.size() % 7))
		_paper_look().apply_to(out)
		out.set_shader_parameter("normal_strength", spec[5])
	_cache[key] = out
	return out


func _paper_look() -> Resource:
	return load("res://data/paper_surfaces/paper_mache.tres")


# --- output --------------------------------------------------------------------------------

func _save(file: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("%s/%s" % [OUT_DIR, file])
	img.save_png(path)
	print("SHOT ", path)


## Mean luminance of a floor patch in front of the player (the close view).
func _lum() -> float:
	var img := root.get_viewport().get_texture().get_image()
	var sz := img.get_size()
	var t := 0.0
	var n := 0
	for y in range(int(sz.y * 0.70), int(sz.y * 0.80), 4):
		for x in range(int(sz.x * 0.40), int(sz.x * 0.50), 4):
			t += img.get_pixel(x, y).get_luminance()
			n += 1
	return t / n


func _frames(n: int) -> void:
	for i in n:
		await process_frame
