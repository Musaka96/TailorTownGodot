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
# fabric_tex_name / pattern_tex_name for the bounds-safe lookup. Cotton and poplin use the
# fine worsted weave (smooth shirtings); only oxford keeps the coarser linen basketweave.
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
# Density of each pattern relative to the texture as drawn, on the pattern only (the
# weave keeps uv_scale). <1 = bolder and wider-spaced, >1 = finer. Tuned so every
# motif still reads as itself on a garment at normal camera distance instead of
# collapsing into speckle; also what gives the shirting patterns that share a texture
# (bengal / university stripe, gingham) their own scale. Indexed by Enums.Pattern.
const PATTERN_SCALE := [
	1.0,  # solid
	1.0,  # pinstripe — the reference density
	0.8,  # herringbone
	0.9,  # houndstooth
	1.0,  # windowpane
	0.85,  # glen check
	0.75,  # birdseye — spaced out so the speckle doesn't vanish at distance
	0.8,  # sharkskin — ditto; it's meant to be a sheen, not a texture
	0.85,  # nailhead
	0.7,  # bengal stripe — wider than a pinstripe
	0.5,  # university stripe — wider still
	1.6,  # gingham — a small check off the windowpane grid
	1.1,  # tattersall
	1.0,  # end-on-end
]
# How strongly each pattern tints the cloth, multiplying the shared pattern_strength.
# The pattern textures store honest coverage, so this is where a pattern's INTENSITY
# is tuned: a two-tone check like houndstooth covers half the cloth and needs far
# less than a pinstripe covering a sixteenth, or it swamps the colour the customer
# was quoted. Indexed by Enums.Pattern; no texture rebuild needed to change these.
const PATTERN_INTENSITY := [
	1.0,  # solid — unused, the texture is blank
	0.85,  # pinstripe
	0.24,  # herringbone — woven, so half coverage
	0.28,  # houndstooth — ditto, and the boldest pattern in the book
	0.72,  # windowpane
	0.60,  # glen check
	0.62,  # birdseye
	0.22,  # sharkskin — meant to be a sheen
	0.55,  # nailhead
	0.85,  # bengal stripe
	0.85,  # university stripe
	0.70,  # gingham
	0.60,  # tattersall
	1.0,  # end-on-end
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
	sm.set_shader_parameter("fabric_tex", texture("fabrics", fabric_tex_name(mat.fabric)))
	sm.set_shader_parameter("pattern_tex", texture("patterns", pattern_tex_name(mat.pattern)))
	sm.set_shader_parameter("pattern_scale", pattern_scale(mat.pattern))
	sm.set_shader_parameter("pattern_intensity", pattern_intensity(mat.pattern))


static func fabric_tex_name(f: int) -> String:
	return FABRIC_TEX[f] if f >= 0 and f < FABRIC_TEX.size() else "linen"


static func pattern_tex_name(p: int) -> String:
	return PATTERN_TEX[p] if p >= 0 and p < PATTERN_TEX.size() else "solid"


static func pattern_scale(p: int) -> float:
	return PATTERN_SCALE[p] if p >= 0 and p < PATTERN_SCALE.size() else 1.0


static func pattern_intensity(p: int) -> float:
	return PATTERN_INTENSITY[p] if p >= 0 and p < PATTERN_INTENSITY.size() else 1.0


static func _base_material(path: String) -> ShaderMaterial:
	if path == BASE_TRIPLANAR_PATH:
		if _base_tri == null and ResourceLoader.exists(path):
			_base_tri = load(path) as ShaderMaterial
		return _base_tri
	if _base == null and ResourceLoader.exists(path):
		_base = load(path) as ShaderMaterial
	return _base


## The weave / pattern texture by folder and name — shared with the UI swatch so
## both show the same cloth.
static func texture(kind: String, name: String) -> Texture2D:
	return load("res://assets/textures/%s/%s.png" % [kind, name])
