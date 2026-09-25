class_name PaperSurface
extends Resource

## The papier-mache surface of a cut-paper character (docs/FACE_STYLE_GUIDE.md, "Papier-mache
## surface"): a scanned paper and a layer of torn paper strips over the skin, the hands and
## the hair, drawn by assets/shaders/paper_mache.gdshaderinc in skin_face.gdshader and
## paper_skin.gdshader. Every field is the shader uniform of the same name; apply_to() writes
## them all. Presets live in data/paper_surfaces/ (CharacterRig.paper_surface picks one).
## Sizes are in FACE UNITS (face_sdf.gdshaderinc), so one preset lands the same on every mesh.

## The scan's colour: only its light and dark are used (the palette stays closed).
@export var scan_albedo_tex: Texture2D
## The scan's OpenGL normal map.
@export var scan_normal_tex: Texture2D
## Scan tiles per face unit.
@export var scan_scale := 2.0
## How much of the scan's light and dark shows (0 = none, 1 = as scanned).
@export_range(0.0, 2.0) var scan_albedo := 0.0
## The scan normal's slope, x (0 = flat).
@export_range(0.0, 4.0) var normal_strength := 0.0
## Strip cells per face unit (a strip is about two cells long, one wide).
@export var mache_scale := 4.0
## Strip relief: 1 = each strip a paper's thickness proud of the one below.
@export_range(0.0, 4.0) var mache_strength := 0.0
## The glue seam's darkness along visible strip edges (with a lighter torn fringe inside).
@export_range(0.0, 1.0) var mache_seam := 0.0
## Each strip's own tone, +- (0.04 = 4 %).
@export_range(0.0, 0.2) var mache_tone := 0.0
## The face pieces' own step on the head: 1 = one paper thick.
@export_range(0.0, 4.0) var piece_relief := 0.0


## Write every field into a paper material (skin_face.gdshader or paper_skin.gdshader).
func apply_to(mat: ShaderMaterial) -> void:
	if mat == null:
		return
	for key: String in [
		"scan_albedo_tex",
		"scan_normal_tex",
		"scan_scale",
		"scan_albedo",
		"normal_strength",
		"mache_scale",
		"mache_strength",
		"mache_seam",
		"mache_tone",
		"piece_relief",
	]:
		mat.set_shader_parameter(key, get(key))
