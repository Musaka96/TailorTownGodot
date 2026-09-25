extends RefCounted

## Runtime photo-grain override for the preview shots (tools/shot_env_grain.gd, and
## tools/shot_mirror.gd grain=...). Nothing is baked: every surface whose texture set has
## a grained copy in `grain_dir` (made by tools/cloth_refs/make_env_grain_preview.py) gets
## a duplicate material using that albedo + normal as its surface override. Which sets
## are grained is simply which files are in the folder, so a preset is a folder.
##   const EnvGrain := preload("res://tools/env_grain_override.gd")
##   var grain := EnvGrain.new(EnvGrain.dir_for("short"))
##   grain.apply(get_root())
##   grain.report()
##
## The set of a surface comes from its albedo image's name (the glTF keeps
## "plaster_albedo", the station glbs extract "<model>_st_grain_albedo", a shop look's
## lives in shop_looks/ and becomes sl_<set>), else from the material name through
## build_town_kit.py's PAL/TEX_SETS (NAME_SETS below). The cut walls (WallCutaway) already
## draw through their own ShaderMaterials: those are patched in place (albedo_tex /
## normal_tex), so the cut walls show the grain too.

const CUTAWAY_SHADER := "res://materials/wall_cutaway.gdshader"
const DIRS := {"full": "res://.dev/env_grain/", "short": "res://.dev/env_grain_short/"}
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

var grain_dir := ""
var counts := {}  # set -> surfaces changed
var unmatched := {}  # "material (set)" -> surfaces left alone
var _textures := {}  # set -> [albedo ImageTexture, normal ImageTexture or null], or null
var _dupes := {}  # original material -> grained duplicate
var _patched := {}  # cutaway ShaderMaterial -> true


func _init(dir: String) -> void:
	grain_dir = dir


## The grain folder for a preset name ("full" or "short").
static func dir_for(preset: String) -> String:
	return DIRS.get(preset, DIRS["full"])


func apply(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			_grain_surface(mi, s)


func report() -> void:
	print("--- surfaces grained, per set (%s) ---" % grain_dir)
	var sets: Array = counts.keys()
	sets.sort()
	for set_name: String in sets:
		print("  %-26s %d" % [set_name, counts[set_name]])
	print("--- materials that matched nothing (surfaces) ---")
	var names: Array = unmatched.keys()
	names.sort()
	for key: String in names:
		print("  %-40s %d" % [key, unmatched[key]])


func _grain_surface(mi: MeshInstance3D, s: int) -> void:
	var mat := mi.get_active_material(s)
	if mat is ShaderMaterial:
		_grain_cutaway(mat as ShaderMaterial)
		return
	var base := mat as BaseMaterial3D
	if base == null:
		return
	var tex := base.get_texture(BaseMaterial3D.TEXTURE_ALBEDO)
	var set_name := set_of_texture(tex)
	if set_name.is_empty() or not _has_set(set_name):
		var by_name := _set_of_name(base.resource_name)
		if not by_name.is_empty() and (set_name.is_empty() or _has_set(by_name)):
			set_name = by_name
	if not _has_set(set_name):
		var key := "%s (%s)" % [base.resource_name, set_name if set_name != "" else "no texture"]
		unmatched[key] = int(unmatched.get(key, 0)) + 1
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
	counts[set_name] = int(counts.get(set_name, 0)) + 1


## A cut wall's cutaway material: patched in place, once, since WallCutaway shares it.
func _grain_cutaway(mat: ShaderMaterial) -> void:
	if mat.shader == null or mat.shader.resource_path != CUTAWAY_SHADER:
		return
	var set_name := set_of_texture(mat.get_shader_parameter("albedo_tex") as Texture2D)
	if not _has_set(set_name):
		var key := "cutaway (%s)" % set_name
		unmatched[key] = int(unmatched.get(key, 0)) + 1
		return
	if not _patched.has(mat):
		var pair: Array = _textures[set_name]
		mat.set_shader_parameter("albedo_tex", pair[0])
		if pair[1] != null:
			mat.set_shader_parameter("normal_tex", pair[1])
			mat.set_shader_parameter("normal_on", true)
		_patched[mat] = true
	var key2 := set_name + " (cut wall)"
	counts[key2] = int(counts.get(key2, 0)) + 1


## "plaster_albedo.png" -> plaster, "sewing_v1_st_grain_albedo.jpg" -> st_grain,
## a shop look's "shop_looks/plaster_albedo.png" -> sl_plaster.
static func set_of_texture(tex: Texture2D) -> String:
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


## Loads <grain_dir>/<set>_{albedo,normal}.png once (straight from disk: .dev/ is not
## imported), with mipmaps. False when the set has no grained copy.
func _has_set(set_name: String) -> bool:
	if set_name.is_empty():
		return false
	if _textures.has(set_name):
		return _textures[set_name] != null
	var albedo := _load_texture(grain_dir + set_name + "_albedo.png", false)
	if albedo == null:
		_textures[set_name] = null
		return false
	_textures[set_name] = [albedo, _load_texture(grain_dir + set_name + "_normal.png", true)]
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
