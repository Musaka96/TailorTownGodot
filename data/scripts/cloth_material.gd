class_name ClothMaterial

## Builds a 3D ShaderMaterial (materials/cloth.gdshader) from a MaterialType so
## world items show the real colour + fabric weave + pattern, not just a flat
## colour. Shared by rolls, cut pieces, garment parts and suits.

const SHADER := preload("res://materials/cloth.gdshader")
const SHADER_TRIPLANAR := preload("res://materials/cloth_triplanar.gdshader")
const SHADER_OUTLINE := preload("res://materials/cloth_outline.gdshader")
# Dark comic-style rim drawn around each garment part (as a next_pass) — see build(outline).
const OUTLINE_WIDTH := 0.005
const OUTLINE_COLOR := Color(0.06, 0.05, 0.07)
# Editable base materials every item shares (tools/build_cloth_materials.gd). Each
# build() duplicates the base and sets only the per-item colour/pattern/fabric, so
# edits to these .tres (or the shader) flow to all cloth. Falls back to a bare
# ShaderMaterial if the .tres is missing.
const BASE_PATH := "res://materials/cloth.tres"
const BASE_TRIPLANAR_PATH := "res://materials/cloth_triplanar.tres"

# Indexed by Enums.Fabric / Enums.Pattern (mirrors the UI swatch mapping). The
# shirting fabrics/patterns reuse the closest existing weave texture (greybox) — see
# _fabric_tex / _pattern_tex for the bounds-safe lookup. Cotton and poplin use the fine
# worsted weave (smooth shirtings); only oxford keeps the coarser linen basketweave.
const FABRIC_TEX := [
	"worsted", "flannel", "tweed", "mohair", "linen", "worsted", "worsted", "linen"
]
const PATTERN_TEX := [
	"solid",
	"pinstripe",
	"herringbone",
	"houndstooth",
	"windowpane",
	"glen_check",
	"birdseye",
	"sharkskin",
	"nailhead",
	"pinstripe",
	"pinstripe",
	"windowpane",
	"glen_check",
	"solid",
]

static var _base: ShaderMaterial
static var _base_tri: ShaderMaterial
static var _outline: ShaderMaterial


static func build(mat: MaterialType, uv_scale := 2.5, outline := false) -> ShaderMaterial:
	var sm := _instance(_base_material(BASE_PATH), SHADER)
	sm.set_shader_parameter("uv_scale", uv_scale)
	_apply(sm, mat)
	if outline:
		sm.next_pass = outline_material()
	return sm


## Triplanar variant for characters: projects the fabric in object space so it
## doesn't stretch over a hand-unwrapped mesh. `tri_scale` = repeats per metre.
static func build_triplanar(
	mat: MaterialType, tri_scale := 3.0, outline := false
) -> ShaderMaterial:
	var sm := _instance(_base_material(BASE_TRIPLANAR_PATH), SHADER_TRIPLANAR)
	sm.set_shader_parameter("tri_scale", tri_scale)
	_apply(sm, mat)
	if outline:
		sm.next_pass = outline_material()
	return sm


## Shared inverted-hull outline material, used as a next_pass to rim garment parts.
static func outline_material() -> ShaderMaterial:
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = SHADER_OUTLINE
		_outline.set_shader_parameter("outline_width", OUTLINE_WIDTH)
		_outline.set_shader_parameter("outline_color", OUTLINE_COLOR)
	return _outline


## A per-item copy of the shared base (keeping its editable global look), or a bare
## ShaderMaterial on the shader if the base .tres is missing.
static func _instance(base: ShaderMaterial, shader: Shader) -> ShaderMaterial:
	if base != null:
		return base.duplicate() as ShaderMaterial
	var sm := ShaderMaterial.new()
	sm.shader = shader
	return sm


## Set the per-item colour/pattern/fabric on a material (leaves the base's globals).
static func _apply(sm: ShaderMaterial, mat: MaterialType) -> void:
	if mat == null:
		return
	sm.set_shader_parameter("cloth_color", mat.cloth_color)
	sm.set_shader_parameter("pattern_color", mat.pattern_color)
	sm.set_shader_parameter("fabric_tex", _tex("fabrics", _fabric_tex(mat.fabric)))
	sm.set_shader_parameter("pattern_tex", _tex("patterns", _pattern_tex(mat.pattern)))


static func _fabric_tex(f: int) -> String:
	return FABRIC_TEX[f] if f >= 0 and f < FABRIC_TEX.size() else "linen"


static func _pattern_tex(p: int) -> String:
	return PATTERN_TEX[p] if p >= 0 and p < PATTERN_TEX.size() else "solid"


static func _base_material(path: String) -> ShaderMaterial:
	if path == BASE_TRIPLANAR_PATH:
		if _base_tri == null and ResourceLoader.exists(path):
			_base_tri = load(path) as ShaderMaterial
		return _base_tri
	if _base == null and ResourceLoader.exists(path):
		_base = load(path) as ShaderMaterial
	return _base


static func _tex(kind: String, name: String) -> Texture2D:
	return load("res://assets/textures/%s/%s.png" % [kind, name])
