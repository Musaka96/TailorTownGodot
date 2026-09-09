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
	mat.set_shader_parameter("fabric_strength", 0.5)
	mat.set_shader_parameter("pattern_strength", 0.85)
	mat.set_shader_parameter(scale_param, scale)
	var err := ResourceSaver.save(mat, path)
	print("build_cloth_materials: %s -> %s" % [path, "ok" if err == OK else "FAIL %d" % err])
