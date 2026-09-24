extends SceneTree

## Generates the editable BASE cloth materials that every fabric item shares:
##   res://materials/cloth.tres           (cloth.gdshader)
##   res://materials/cloth_triplanar.tres (cloth_triplanar.gdshader)
##
## ClothMaterial.build() duplicates the matching base and sets only the per-item
## colour/pattern/fabric, so editing these .tres (fabric/pattern strength, adding a
## normal map, tweaking defaults) or the shader itself changes how ALL cloth renders
## while each roll/piece/suit still shows the fabric the customer chose.
## Also the shoe leather base, res://materials/leather.tres (leather.gdshader), which
## ShoeMaterial.build() duplicates the same way (colour + finish per shoe).
##   godot --headless --path . --script res://tools/build_cloth_materials.gd

const CLOTH := "res://materials/cloth.tres"
const CLOTH_TRI := "res://materials/cloth_triplanar.tres"
const LEATHER := "res://materials/leather.tres"


func _initialize() -> void:
	_write(CLOTH, "res://materials/cloth.gdshader", "uv_scale", 2.5)
	_write(CLOTH_TRI, "res://materials/cloth_triplanar.gdshader", "tri_scale", 3.0)
	_write_leather()
	quit(0)


## Leather: standard PBR, the grain drives roughness. Defaults = black calf; the
## per-finish values (roughness, clearcoat, normal depth, grain) are ShoeMaterial.FINISH_PARAMS.
func _write_leather() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://materials/leather.gdshader")
	mat.set_shader_parameter("leather_color", Color("141416"))
	mat.set_shader_parameter("grain_tex", load("res://assets/textures/grain/leather_calf.png"))
	mat.set_shader_parameter("grain_normal", load("res://assets/textures/grain/leather_calf_n.png"))
	mat.set_shader_parameter("grain_mean", 0.25)
	mat.set_shader_parameter("grain_scale", 4.0)
	mat.set_shader_parameter("grain_strength", 1.0)
	mat.set_shader_parameter("grain_contrast", 1.0)
	mat.set_shader_parameter("normal_depth", 1.0)
	mat.set_shader_parameter("roughness_base", 0.45)
	mat.set_shader_parameter("roughness_grain", 0.25)
	mat.set_shader_parameter("specular", 0.5)
	mat.set_shader_parameter("clearcoat", 0.0)
	mat.set_shader_parameter("clearcoat_roughness", 0.2)
	var err := ResourceSaver.save(mat, LEATHER)
	print("build_cloth_materials: %s -> %s" % [LEATHER, "ok" if err == OK else "FAIL %d" % err])


func _write(path: String, shader_path: String, scale_param: String, scale: float) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load(shader_path)
	# Global look, editable in the inspector; per-item colour/pattern are set at runtime.
	# The previous (v2) look is grain_strength 0 + fabric_strength 0.5 + normal_depth 1.8
	# + pattern_fuzz 0 + wrap 0 (sheen/aniso are per fabric, ClothMaterial.FABRIC_SHEEN
	# / FABRIC_ANISO; the lab's "v2" preset sets it all back).
	mat.set_shader_parameter("fabric_strength", 0.2)
	mat.set_shader_parameter("pattern_strength", 0.85)
	mat.set_shader_parameter("pattern_relief", 0.85)
	# Rim sheen falloff (higher = thinner rim) and tint (0 = white sheen, 1 = cloth-coloured);
	# the strength is per fabric (ClothMaterial.FABRIC_RIM).
	mat.set_shader_parameter("rim_power", 3.0)
	mat.set_shader_parameter("rim_tint", 0.4)
	# B2/B4 live values (the shader defaults are 0 = off, the regression guard):
	# weave normal-map depth, and the macro brightness breakup per metre of cloth.
	# Above v2's 1.8: the combo look from the post study wants the grain to read deeper.
	mat.set_shader_parameter("normal_depth", 2.2)
	mat.set_shader_parameter("macro_strength", 0.12)
	mat.set_shader_parameter("macro_scale", 0.35)
	# Cloth Look v3 (the shader defaults are all off = v2): the per-fabric scanned grain
	# (ClothMaterial.FABRIC_GRAIN) multiplies under the dye and replaces the weave normal,
	# pattern edges fuzz with it, and the light wraps and sheens like cloth.
	mat.set_shader_parameter("grain_strength", 1.0)
	mat.set_shader_parameter("grain_scale", 1.85)
	mat.set_shader_parameter("grain_contrast", 1.4)
	mat.set_shader_parameter("pattern_fuzz", 1.0)
	mat.set_shader_parameter("wrap", 0.35)
	mat.set_shader_parameter("sheen_roughness", 0.8)
	mat.set_shader_parameter("sheen_tint", 0.5)
	mat.set_shader_parameter("aniso_shine", 40.0)
	# Mohair's streak takes the cloth colour, not a white glint.
	mat.set_shader_parameter("aniso_tint", 0.9)
	mat.set_shader_parameter(scale_param, scale)
	var err := ResourceSaver.save(mat, path)
	print("build_cloth_materials: %s -> %s" % [path, "ok" if err == OK else "FAIL %d" % err])
