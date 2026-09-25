class_name ShoeMaterial

## Builds a shoe's leather ShaderMaterial (materials/leather.gdshader) from a colour id
## and a finish, the way ClothMaterial does for cloth: duplicate the editable base
## (materials/leather.tres, tools/build_cloth_materials.gd) and set only the per-shoe
## colour, grain and finish. Leather keeps the engine's PBR light with a soft GGX
## highlight; its grain drives roughness.

const SHADER := preload("res://materials/leather.gdshader")
const BASE_PATH := "res://materials/leather.tres"
## Grain tiles per UV unit at uv_scale 1 (the base material's grain_scale).
const GRAIN_SCALE := 4.0
const COLORS := {
	"black": Color("141416"),
	"dark_brown": Color("3a2a1e"),
	"oxblood": Color("4a1d1e"),
	"tan": Color("8f6a40"),
	"chestnut": Color("6b3f24"),
	# Off-white for sneakers (street clothes); not among the random picks below.
	"white": Color("e6e2d8"),
}
const FINISHES := ["calf", "pebble", "patent"]
# Per finish: the grain tile (assets/textures/grain/<name>.png + _n) and the leather
# shader's roughness / clearcoat / normal depth. Patent is a smooth lacquer coat over
# calf, so its grain barely shows and the clearcoat does the shine.
const FINISH_PARAMS := {
	"calf":
	{
		"grain": "leather_calf",
		"roughness_base": 0.45,
		"roughness_grain": 0.25,
		"clearcoat": 0.0,
		"clearcoat_roughness": 0.2,
		"normal_depth": 1.0,
	},
	"pebble":
	{
		"grain": "leather_pebble",
		"roughness_base": 0.6,
		"roughness_grain": 0.25,
		"clearcoat": 0.0,
		"clearcoat_roughness": 0.2,
		"normal_depth": 1.6,
	},
	"patent":
	{
		"grain": "leather_calf",
		"roughness_base": 0.12,
		"roughness_grain": 0.05,
		"clearcoat": 0.6,
		"clearcoat_roughness": 0.08,
		"normal_depth": 0.3,
	},
}
# Weighted picks for random(): [id, weight], weights summing to 100.
const COLOR_WEIGHTS := [
	["black", 40], ["dark_brown", 25], ["chestnut", 15], ["tan", 12], ["oxblood", 8]
]
const FINISH_WEIGHTS := [["calf", 65], ["pebble", 25], ["patent", 10]]
const DEFAULT_COLOR := "black"
const DEFAULT_FINISH := "calf"

static var _base: ShaderMaterial


## A per-shoe leather material. Unknown ids fall back to black calf; uv_scale
## multiplies the grain density like ClothMaterial's uv_scale.
static func build(
	color_id: String, finish: String, uv_scale: float = 1.0, outline: bool = false
) -> ShaderMaterial:
	var sm: ShaderMaterial
	if _base_material() != null:
		sm = _base.duplicate() as ShaderMaterial
	else:
		sm = ShaderMaterial.new()
		sm.shader = SHADER
	var d := from_dict({"color": color_id, "finish": finish})
	var params: Dictionary = FINISH_PARAMS[d["finish"]]
	sm.set_shader_parameter("leather_color", COLORS[d["color"]])
	sm.set_shader_parameter("grain_scale", GRAIN_SCALE * uv_scale)
	for key: String in [
		"roughness_base", "roughness_grain", "clearcoat", "clearcoat_roughness", "normal_depth"
	]:
		sm.set_shader_parameter(key, params[key])
	var grain: String = params["grain"]
	sm.set_shader_parameter("grain_tex", ClothMaterial.texture("grain", grain))
	sm.set_shader_parameter("grain_normal", ClothMaterial.texture("grain", grain + "_n"))
	if outline:
		sm.next_pass = ClothMaterial.outline_material()
	return sm


## A weighted random shoe: {"color": id, "finish": finish}.
static func random(rng: RandomNumberGenerator) -> Dictionary:
	return {"color": _pick(rng, COLOR_WEIGHTS), "finish": _pick(rng, FINISH_WEIGHTS)}


## {"color", "finish"} with missing or unknown values replaced by black calf.
static func from_dict(d: Dictionary) -> Dictionary:
	var color_id := String(d.get("color", DEFAULT_COLOR))
	var finish := String(d.get("finish", DEFAULT_FINISH))
	if not COLORS.has(color_id):
		color_id = DEFAULT_COLOR
	if not FINISH_PARAMS.has(finish):
		finish = DEFAULT_FINISH
	return {"color": color_id, "finish": finish}


static func _pick(rng: RandomNumberGenerator, table: Array) -> String:
	var total := 0
	for entry: Array in table:
		total += int(entry[1])
	var roll := rng.randi_range(0, total - 1)
	for entry: Array in table:
		roll -= int(entry[1])
		if roll < 0:
			return String(entry[0])
	return String(table[0][0])


static func _base_material() -> ShaderMaterial:
	if _base == null and ResourceLoader.exists(BASE_PATH):
		_base = load(BASE_PATH) as ShaderMaterial
	return _base
