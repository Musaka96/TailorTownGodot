extends SceneTree

## Builds the decorative prop scenes + materials for the grass, carpet and toon shaders:
##   materials/grass.tres, materials/carpet.tres, materials/toon.tres
##   scenes/props/grass_patch.tscn  (a turf block with wind-swayed billboard blades)
##   scenes/props/carpet.tscn       (a flat rug you can drop any carpet texture onto)
## toon.tres is a ready-to-apply cel material (drop on any mesh's Material Override).
## Default textures are embedded in the materials (no PNG/import step needed); swap the
## carpet's texture in the inspector to recreate any rug.
##   godot --headless --path . --script res://tools/build_props.gd

const GRASS_SHADER := "res://materials/grass.gdshader"
const CARPET_SHADER := "res://materials/carpet.gdshader"
const TOON_SHADER := "res://materials/toon.gdshader"
const MAT_DIR := "res://materials/"
const SCENE_DIR := "res://scenes/props/"

const BLOCK_SIZE := 2.0  # grass patch is BLOCK_SIZE x BLOCK_SIZE metres
const BLADE_COUNT := 420
const BLADE_W := 0.34
const BLADE_H := 0.42


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENE_DIR))
	var fails := 0
	fails += _save(_grass_material(), MAT_DIR + "grass.tres")
	fails += _save(_carpet_material(), MAT_DIR + "carpet.tres")
	fails += _save(_toon_material(), MAT_DIR + "toon.tres")
	fails += _save(_grass_scene(), SCENE_DIR + "grass_patch.tscn")
	fails += _save(_carpet_scene(), SCENE_DIR + "carpet.tscn")
	print("build_props: done, %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)


func _save(res: Resource, path: String) -> int:
	if ResourceSaver.save(res, path) == OK:
		print("  wrote ", path)
		return 0
	printerr("  FAILED ", path)
	return 1


# --- Materials -------------------------------------------------------------


func _grass_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(GRASS_SHADER)
	m.set_shader_parameter("billboard", true)
	m.set_shader_parameter("shape_texture", _blade_shape())
	m.set_shader_parameter("use_atlas", false)
	m.set_shader_parameter("noise_texture", _noise(0.06, 3, false))
	m.set_shader_parameter("color_gradient", _grass_gradient())
	m.set_shader_parameter("random_variation", 0.03)
	m.set_shader_parameter("wind_texture", _noise(0.5, 4, true))
	m.set_shader_parameter("wind_velocity", Vector2(1.0, 0.35))
	m.set_shader_parameter("alpha_mode", 2)  # Cut — clean opaque blades
	m.set_shader_parameter("alpha_cut_start", 0.25)
	m.set_shader_parameter("alpha_cut_end", 0.6)
	return m


## A ready-to-apply cel-shading material using the untouched linked toon shader. Drop it on
## any mesh's Material Override. A white albedo/specular texture is supplied so meshes render
## in the `albedo` colour (the shader multiplies albedo by these textures).
func _toon_material() -> ShaderMaterial:
	var white := Image.create(2, 2, false, Image.FORMAT_RGB8)
	white.fill(Color(1, 1, 1))
	var tex := ImageTexture.create_from_image(white)
	var m := ShaderMaterial.new()
	m.shader = load(TOON_SHADER)
	m.set_shader_parameter("albedo", Color(0.85, 0.85, 0.88))
	m.set_shader_parameter("albedo_texture", tex)
	m.set_shader_parameter("specular_map", tex)
	m.set_shader_parameter("cuts", 3)
	m.set_shader_parameter("use_specular", true)
	m.set_shader_parameter("use_rim", true)
	return m


func _carpet_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(CARPET_SHADER)
	m.set_shader_parameter("carpet_texture", _carpet_texture())
	m.set_shader_parameter("use_texture", true)
	m.set_shader_parameter("tint", Color(1, 1, 1, 1))
	m.set_shader_parameter("tiling", Vector2(2.0, 2.0))
	m.set_shader_parameter("pile_strength", 0.18)
	m.set_shader_parameter("pile_scale", 90.0)
	m.set_shader_parameter("fringe_width", 0.045)
	m.set_shader_parameter("fringe_color", Color(0.86, 0.80, 0.66))
	return m


# --- Generated textures (embedded in the materials) ------------------------


## A little cluster of tapering blades, white on black — the shader reads .r as the alpha.
func _blade_shape() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_L8)
	img.fill(Color(0, 0, 0))
	var blades := [0.30, 0.5, 0.70]
	var half := [0.10, 0.13, 0.10]
	for px in size:
		for py in size:
			var u := float(px) / float(size - 1)
			var v := float(py) / float(size - 1)  # 0 = top, 1 = bottom
			var on := 0.0
			for i in blades.size():
				var w: float = half[i] * v  # narrows toward the top
				if absf(u - blades[i]) <= w and v > 0.06:
					on = 1.0
			img.set_pixel(px, py, Color(on, on, on))
	return ImageTexture.create_from_image(img)


## A simple woven rug: warm ground with a lighter diamond lattice + border band.
func _carpet_texture() -> ImageTexture:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var ground := Color(0.55, 0.16, 0.18)
	var motif := Color(0.80, 0.62, 0.36)
	# A seamless diamond lattice only — the single rug border comes from the shader's
	# `fringe`, so the pattern tiles without drawing internal grid lines.
	for px in size:
		for py in size:
			var u := float(px) / float(size)
			var v := float(py) / float(size)
			var col := ground
			var d := absf(fract(u * 6.0) - 0.5) + absf(fract(v * 6.0) - 0.5)
			if d < 0.16:
				col = motif
			img.set_pixel(px, py, col)
	return ImageTexture.create_from_image(img)


func _noise(freq: float, octaves: int, seamless: bool) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = seamless
	t.noise = n
	return t


func _grass_gradient() -> GradientTexture1D:
	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, Color(0.16, 0.32, 0.12))  # shaded blade base
	g.add_point(0.5, Color(0.30, 0.52, 0.18))
	g.set_color(1, Color(0.52, 0.72, 0.30))  # sunlit tip
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 128
	return t


# --- Scenes ----------------------------------------------------------------


func _grass_scene() -> PackedScene:
	var root := Node3D.new()
	root.name = "GrassPatch"
	root.set_script(load("res://scenes/props/grass_patch.gd"))
	root.set("block_size", BLOCK_SIZE)
	root.set("blade_count", BLADE_COUNT)

	# Turf base so it reads as a solid block of grass.
	var base := MeshInstance3D.new()
	base.name = "Turf"
	var box := BoxMesh.new()
	box.size = Vector3(BLOCK_SIZE, 0.2, BLOCK_SIZE)
	base.mesh = box
	base.position = Vector3(0, -0.1, 0)  # top face sits at y = 0
	var soil := StandardMaterial3D.new()
	soil.albedo_color = Color(0.22, 0.34, 0.14)
	soil.roughness = 1.0
	soil.metallic_specular = 0.0
	base.material_override = soil
	root.add_child(base)
	base.owner = root

	# Billboard blades scattered over the top.
	var blades := MultiMeshInstance3D.new()
	blades.name = "Blades"
	var quad := QuadMesh.new()
	quad.size = Vector2(BLADE_W, BLADE_H)
	quad.center_offset = Vector3(0, BLADE_H * 0.5, 0)  # pivot at the blade base
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	# Instances are populated at runtime by grass_patch.gd (the transform buffer does not
	# serialise reliably from a headless build), so none are baked here.
	blades.multimesh = mm
	blades.material_override = load(MAT_DIR + "grass.tres")
	root.add_child(blades)
	blades.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	return packed


func _carpet_scene() -> PackedScene:
	var root := Node3D.new()
	root.name = "Carpet"
	root.set_script(load("res://scenes/props/carpet.gd"))
	var rug := MeshInstance3D.new()
	rug.name = "Rug"
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.4, 1.6)
	rug.mesh = plane
	rug.position = Vector3(0, 0.01, 0)  # just above the floor to avoid z-fighting
	rug.material_override = load(MAT_DIR + "carpet.tres")
	root.add_child(rug)
	rug.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	return packed


func fract(x: float) -> float:
	return x - floor(x)
