class_name ClothMaterial

## Builds a 3D ShaderMaterial (materials/cloth.gdshader) from a MaterialType so
## world items show the real colour + fabric weave + pattern, not just a flat
## colour. Shared by rolls, cut pieces, garment parts and suits.

const SHADER := preload("res://materials/cloth.gdshader")
const SHADER_TRIPLANAR := preload("res://materials/cloth_triplanar.gdshader")

# Indexed by Enums.Fabric / Enums.Pattern (mirrors the UI swatch mapping).
const FABRIC_TEX := ["worsted", "flannel", "tweed", "mohair", "linen"]
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
]


static func build(mat: MaterialType, uv_scale := 2.5) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = SHADER
	sm.set_shader_parameter("uv_scale", uv_scale)
	if mat != null:
		sm.set_shader_parameter("cloth_color", mat.cloth_color)
		sm.set_shader_parameter("pattern_color", mat.pattern_color)
		sm.set_shader_parameter("fabric_tex", _tex("fabrics", FABRIC_TEX[mat.fabric]))
		sm.set_shader_parameter("pattern_tex", _tex("patterns", PATTERN_TEX[mat.pattern]))
	return sm


## Triplanar variant for characters: projects the fabric in object space so it
## doesn't stretch over a hand-unwrapped mesh. `tri_scale` = repeats per metre.
static func build_triplanar(mat: MaterialType, tri_scale := 3.0) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = SHADER_TRIPLANAR
	sm.set_shader_parameter("tri_scale", tri_scale)
	if mat != null:
		sm.set_shader_parameter("cloth_color", mat.cloth_color)
		sm.set_shader_parameter("pattern_color", mat.pattern_color)
		sm.set_shader_parameter("fabric_tex", _tex("fabrics", FABRIC_TEX[mat.fabric]))
		sm.set_shader_parameter("pattern_tex", _tex("patterns", PATTERN_TEX[mat.pattern]))
	return sm


static func _tex(kind: String, name: String) -> Texture2D:
	return load("res://assets/textures/%s/%s.png" % [kind, name])
