class_name TieMaterial
extends RefCounted

## The tie's cloth: the garments' own cloth shader (ClothMaterial; the tie's UVs are in
## metres like the jacket's) as a fine silk twill in the rig's tie_color, rather than a
## flat colour. The weave is tight and faint (a 2/2 twill, the sharkskin texture, a touch
## lighter than the ground) and the light it catches is a soft coloured satin sheen: the
## shader stays matte (roughness 1, no specular), so there is no gloss to read as plastic.
## Street ties are muted knits: the same cloth, flannel-grained, no twill, less sheen.

## Weave tiles per metre of tie (suits use CharacterRig.CLOTH_UV_SCALE, 6): a little
## finer than a worsted; finer still and the twill dissolves into a flat colour on screen.
const UV_SCALE := 8.0
## The twill's density over the weave and its strength (ClothMaterial's pattern dials):
## diagonals about 5 mm apart on the tie, faint (sharkskin's own is 0.22, a pinstripe 0.85).
const TWILL_SCALE := 0.75
const TWILL_INTENSITY := 0.4
## How much lighter the twill's raised lines are than the ground.
const TWILL_LIFT := 0.1
## Satin sheen (the shader's Charlie lobe): strength, spread and how much of the tie's
## own colour it takes.
const SHEEN := 0.9
const SHEEN_ROUGHNESS := 0.35
const SHEEN_TINT := 0.8
## The scanned grain and the thread relief, softer than on suit cloth (silk is smooth).
const GRAIN := 0.45
const RELIEF := 1.2
const KNIT_SHEEN := 0.25


## Put the tie cloth (with the garments' outline) on `mi` when it is a mesh.
static func dress(mi: Variant, color: Color, knit := false) -> void:
	if mi is MeshInstance3D:
		(mi as MeshInstance3D).material_override = build(color, knit)


static func build(color: Color, knit := false) -> ShaderMaterial:
	var mat := MaterialType.new()
	mat.cloth_color = color
	mat.pattern_color = color.lightened(TWILL_LIFT)
	mat.fabric = Enums.Fabric.FLANNEL if knit else Enums.Fabric.POPLIN
	mat.pattern = Enums.Pattern.SOLID if knit else Enums.Pattern.SHARKSKIN
	var sm := ClothMaterial.build(mat, UV_SCALE, true)
	sm.set_shader_parameter("pattern_scale", TWILL_SCALE)
	sm.set_shader_parameter("pattern_intensity", TWILL_INTENSITY)
	sm.set_shader_parameter("shot_strength", 0.0)
	sm.set_shader_parameter("rim_strength", 0.0)
	sm.set_shader_parameter("aniso", 0.0)
	sm.set_shader_parameter("sheen_strength", KNIT_SHEEN if knit else SHEEN)
	sm.set_shader_parameter("sheen_roughness", SHEEN_ROUGHNESS)
	sm.set_shader_parameter("sheen_tint", SHEEN_TINT)
	sm.set_shader_parameter("grain_strength", GRAIN)
	sm.set_shader_parameter("normal_depth", RELIEF)
	return sm
