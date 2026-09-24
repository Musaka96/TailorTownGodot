extends SceneTree

## Generates the editable BASE cloth materials that every fabric item shares:
##   res://materials/cloth.tres           (cloth.gdshader)
##   res://materials/cloth_triplanar.tres (cloth_triplanar.gdshader)
##
## ClothMaterial.build() duplicates the matching base and sets only the per-item
## colour/pattern/fabric, so editing these .tres (fabric/pattern strength, adding a
## normal map, tweaking defaults) or the shader itself changes how ALL cloth renders
## while each roll/piece/suit still shows the fabric the customer chose.
##   godot --headless --path . --script res://tools/build_cloth_materials.gd

const CLOTH := "res://materials/cloth.tres"
const CLOTH_TRI := "res://materials/cloth_triplanar.tres"


func _initialize() -> void:
	_write(CLOTH, "res://materials/cloth.gdshader", "uv_scale", 2.5)
	_write(CLOTH_TRI, "res://materials/cloth_triplanar.gdshader", "tri_scale", 3.0)
	quit(0)


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
	# Lower than v2's 1.8: the photo grain normal is strong on its own.
	mat.set_shader_parameter("normal_depth", 1.2)
	mat.set_shader_parameter("macro_strength", 0.12)
	mat.set_shader_parameter("macro_scale", 0.35)
	# Cloth Look v3 (the shader defaults are all off = v2): the per-fabric scanned grain
	# (ClothMaterial.FABRIC_GRAIN) multiplies under the dye and replaces the weave normal,
	# pattern edges fuzz with it, and the light wraps and sheens like cloth.
	mat.set_shader_parameter("grain_strength", 1.0)
	mat.set_shader_parameter("grain_scale", 1.85)
	mat.set_shader_parameter("grain_contrast", 1.0)
	mat.set_shader_parameter("pattern_fuzz", 1.0)
	mat.set_shader_parameter("wrap", 0.25)
	mat.set_shader_parameter("sheen_roughness", 0.8)
	mat.set_shader_parameter("sheen_tint", 0.5)
	mat.set_shader_parameter("aniso_shine", 40.0)
	mat.set_shader_parameter("aniso_tint", 0.6)
	mat.set_shader_parameter(scale_param, scale)
	var err := ResourceSaver.save(mat, path)
	print("build_cloth_materials: %s -> %s" % [path, "ok" if err == OK else "FAIL %d" % err])
