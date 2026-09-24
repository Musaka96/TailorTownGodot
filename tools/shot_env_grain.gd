extends SceneTree

## Before/after shots of photo grain on grandpa's shop and the street: a RUNTIME PREVIEW,
## nothing baked. NOT headless.
##   python tools/cloth_refs/make_env_grain_preview.py        (the grained textures first)
##   godot --path . --script res://tools/shot_env_grain.gd [-- stage=all|day1 settle=N]
##
## Loads main_grandpa.tscn, takes three views with the game's own materials (BEFORE), then
## swaps every surface whose texture set has a grained copy in .dev/env_grain/ for a
## duplicate using that albedo + normal (surface override) and takes them again (AFTER):
##   env_shop_game   the gameplay camera, player just inside the door
##   env_shop_close  inside, low and level: back wall, wainscot, floor and the worktable
##   env_street      outside, low and level: the shop front, the pavement and the door
## Frames go to .dev/env_grain_shots/<view>_{before,after}.png, the AFTER frames also to
## .dev/<view>.png, and make_env_grain_preview.py compose builds .dev/env_grain_compare.png.
##
## The set of a surface comes from its albedo image's name (the glTF keeps
## "plaster_albedo", the station glbs extract "<model>_st_grain_albedo"), else from the
## material name through build_town_kit.py's PAL/TEX_SETS (NAME_SETS below). The cut walls
## (WallCutaway) already draw through their own ShaderMaterials: those are patched in
## place (albedo_tex / normal_tex), so the cut walls show the grain too.

const SCENE := "res://scenes/world/grandpa/main_grandpa.tscn"
const GRAIN_DIR := "res://.dev/env_grain/"
const SHOT_DIR := "res://.dev/env_grain_shots/"
const COMPOSER := "res://tools/cloth_refs/make_env_grain_preview.py"
const CUTAWAY_SHADER := "res://materials/wall_cutaway.gdshader"
const SIZE := Vector2i(1920, 1080)
const STILL_FRAMES := 10
const SETTLE_CAP := 400
const STILL_EPS := 0.0001
## Material name -> texture set, for surfaces whose albedo image name says nothing
## (a copy of the PAL/TEX_SETS tables in IMPORT/town_kit/build_town_kit.py and
## build_v8_grandpa.py, for the mapped sets only).
const NAME_SETS := {
	"brick": "brick",
	"stone": "stone_dressed",
	"stone_dark": "stone_dressed",
	"cobble": "cobble",
	"asphalt": "asphalt",
	"wood_light": "grain_oak",
	"wood": "grain_walnut",
	"wood_red": "grain_mahogany",
	"door_wood": "grain_mahogany",
	"floor_wood": "floor_planks",
	"floor_planks": "floor_planks",
	"Floor": "floor_planks",
	"floor_next_v8": "floor_planks",
	"floor_parquet": "parquet",
	"velvet": "velvet",
	"curtain_green": "velvet",
	"drape_green": "velvet",
	"drape_red": "velvet",
	"Drape": "velvet",
	"upholstery": "plush",
	"cork": "cork",
	"cardboard": "cardboard",
	"curtain": "fabric",
	"linen": "fabric",
	"rug_blue": "fabric",
	"rug_cream": "fabric",
	"rug_navy": "fabric",
	"roof_shed_v8": "canvas",
}
## Material name prefixes -> texture set (the generated PAL families).
const PREFIX_SETS := {
	"wall_": "plaster",
	"cloth_": "fabric",
	"awning_": "canvas",
}

var _args := {}
var _main: Node
var _textures := {}  # set -> [albedo ImageTexture, normal ImageTexture or null]
var _dupes := {}  # original material -> grained duplicate
var _patched := {}  # cutaway ShaderMaterial -> true
var _counts := {}  # set -> surfaces changed
var _unmatched := {}  # "material (set)" -> surfaces left alone


func _initialize() -> void:
	_run()


func _run() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			_args[kv[0]] = kv[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
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
	await _shoot_all("before")
	_apply_grain()
	await _shoot_all("after")
	_report()
	_compose()
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


func _shoot_all(tag: String) -> void:
	var player := _main.find_child("Player", true, false) as Node3D
	var rig: Node = get_first_node_in_group("camera_rig")
	var door_in := _marker("DoorInside", Vector3(0.65, 0.0, 7.7))
	var door_out := _marker("DoorOutside", Vector3(0.65, 0.0, 9.6))
	var table := _main.find_child("Worktable", true, false) as Node3D
	var at: Vector3 = table.global_position if table != null else Vector3(0.6, 0.0, 2.5)
	# (a) the game camera, player just inside the door
	player.visible = true
	player.global_position = door_in + Vector3(0.0, 0.1, -0.4)
	rig.unfocus()
	await _settle()
	_capture("env_shop_game", tag)
	# (b) inside, low and level, facing the back wall and the worktable. The player waits
	# behind the camera (inside, so the front walls stay cut the way they are in play).
	player.visible = false
	var eye := Vector3(at.x - 0.3, 1.0, at.z + 2.3)
	player.global_position = Vector3(eye.x, 0.1, door_in.z - 0.6)
	rig.focus(eye, eye + Vector3(0.0, 0.0, -1.0))
	await _settle()
	_capture("env_shop_close", tag)
	# (c) the street, low and level, facing the shop front and the door
	var street_eye := Vector3(door_out.x + 0.4, 1.3, door_out.z + 5.2)
	player.global_position = street_eye + Vector3(0.0, -1.2, 1.0)
	rig.focus(street_eye, street_eye + Vector3(0.0, 0.0, -1.0))
	await _settle()
	_capture("env_street", tag)
	player.visible = true
	rig.unfocus()


func _marker(marker_name: String, fallback: Vector3) -> Vector3:
	var node := _main.find_child(marker_name, true, false) as Node3D
	return node.global_position if node != null else fallback


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
	var path := ProjectSettings.globalize_path("%s%s_%s.png" % [SHOT_DIR, view, tag])
	image.save_png(path)
	print("Saved ", path, " ", image.get_size())
	if tag == "after":
		image.save_png(ProjectSettings.globalize_path("res://.dev/%s.png" % view))


# --- The swap ----------------------------------------------------------------


func _apply_grain() -> void:
	for node in get_root().find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			_grain_surface(mi, s)


func _grain_surface(mi: MeshInstance3D, s: int) -> void:
	var mat := mi.get_active_material(s)
	if mat is ShaderMaterial:
		_grain_cutaway(mat as ShaderMaterial)
		return
	var base := mat as BaseMaterial3D
	if base == null:
		return
	var tex := base.get_texture(BaseMaterial3D.TEXTURE_ALBEDO)
	var set_name := _set_of_texture(tex)
	if set_name.is_empty() or not _has_set(set_name):
		var by_name := _set_of_name(base.resource_name)
		if not by_name.is_empty() and (set_name.is_empty() or _has_set(by_name)):
			set_name = by_name
	if not _has_set(set_name):
		var key := "%s (%s)" % [base.resource_name, set_name if set_name != "" else "no texture"]
		_unmatched[key] = int(_unmatched.get(key, 0)) + 1
		return
	if not _dupes.has(base):
		var dupe := base.duplicate() as BaseMaterial3D
		var pair: Array = _textures[set_name]
		dupe.set_texture(BaseMaterial3D.TEXTURE_ALBEDO, pair[0])
		if pair[1] != null:
			dupe.normal_enabled = true
			dupe.set_texture(BaseMaterial3D.TEXTURE_NORMAL, pair[1])
		_dupes[base] = dupe
	mi.set_surface_override_material(s, _dupes[base])
	_counts[set_name] = int(_counts.get(set_name, 0)) + 1


## A cut wall's cutaway material: patched in place, once, since WallCutaway shares it.
func _grain_cutaway(mat: ShaderMaterial) -> void:
	if mat.shader == null or mat.shader.resource_path != CUTAWAY_SHADER:
		return
	var set_name := _set_of_texture(mat.get_shader_parameter("albedo_tex") as Texture2D)
	if not _has_set(set_name):
		var key := "cutaway (%s)" % set_name
		_unmatched[key] = int(_unmatched.get(key, 0)) + 1
		return
	if not _patched.has(mat):
		var pair: Array = _textures[set_name]
		mat.set_shader_parameter("albedo_tex", pair[0])
		if pair[1] != null:
			mat.set_shader_parameter("normal_tex", pair[1])
			mat.set_shader_parameter("normal_on", true)
		_patched[mat] = true
	var key2 := set_name + " (cut wall)"
	_counts[key2] = int(_counts.get(key2, 0)) + 1


## "plaster_albedo.png" -> plaster, "sewing_v1_st_grain_albedo.jpg" -> st_grain,
## a shop look's "shop_looks/plaster_albedo.png" -> sl_plaster.
func _set_of_texture(tex: Texture2D) -> String:
	if tex == null:
		return ""
	var path := tex.resource_path
	var stem := (path if path != "" else tex.resource_name).get_file().get_basename()
	if not stem.ends_with("_albedo"):
		return ""
	stem = stem.trim_suffix("_albedo")
	var st := stem.find("_st_")
	if st >= 0:
		stem = stem.substr(st + 1)
	if path.contains("/shop_looks/"):
		stem = "sl_" + stem
	return stem


func _set_of_name(mat_name: String) -> String:
	if NAME_SETS.has(mat_name):
		return NAME_SETS[mat_name]
	for prefix: String in PREFIX_SETS:
		if mat_name.begins_with(prefix):
			return PREFIX_SETS[prefix]
	return ""


## Loads .dev/env_grain/<set>_{albedo,normal}.png once (straight from disk: .dev/ is not
## imported), with mipmaps. False when the set has no grained copy.
func _has_set(set_name: String) -> bool:
	if set_name.is_empty():
		return false
	if _textures.has(set_name):
		return _textures[set_name] != null
	var albedo := _load_texture(GRAIN_DIR + set_name + "_albedo.png", false)
	if albedo == null:
		_textures[set_name] = null
		return false
	_textures[set_name] = [albedo, _load_texture(GRAIN_DIR + set_name + "_normal.png", true)]
	return true


func _load_texture(path: String, normal: bool) -> ImageTexture:
	var file := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(file):
		return null
	var image := Image.load_from_file(file)
	if image == null or image.is_empty():
		return null
	image.generate_mipmaps(normal)
	return ImageTexture.create_from_image(image)


func _report() -> void:
	print("--- surfaces grained, per set ---")
	var sets: Array = _counts.keys()
	sets.sort()
	for set_name: String in sets:
		print("  %-26s %d" % [set_name, _counts[set_name]])
	print("--- materials that matched nothing (surfaces) ---")
	var names: Array = _unmatched.keys()
	names.sort()
	for key: String in names:
		print("  %-40s %d" % [key, _unmatched[key]])


func _compose() -> void:
	var out: Array = []
	var code := OS.execute(
		"python", [ProjectSettings.globalize_path(COMPOSER), "compose"], out, true
	)
	for line: String in out:
		print(line.strip_edges())
	if code != 0:
		push_error("shot_env_grain: composer exited %d" % code)
