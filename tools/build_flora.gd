extends SceneTree

## Builds the flora system: a matte ground material, placeholder grass + flower sprites
## (colour + mask, meant to be replaced in the editor), default FloraElement layers, and
## scenes/props/flora_patch.tscn (ground + scatter). Textures are embedded so no import
## step is needed; swap them per element in the inspector later.
##   godot --headless --path . --import        (once, so FloraElement is known)
##   godot --headless --path . --script res://tools/build_flora.gd

const MAT_DIR := "res://materials/"
const SCENE_DIR := "res://scenes/props/"
const TEX := 96
const PATCH := Vector2(3.0, 3.0)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENE_DIR))
	var fails := 0
	fails += _save(_ground_material(), MAT_DIR + "ground.tres")
	fails += _save(_flora_scene(), SCENE_DIR + "flora_patch.tscn")
	print("build_flora: done, %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)


func _save(res: Resource, path: String) -> int:
	if ResourceSaver.save(res, path) == OK:
		print("  wrote ", path)
		return 0
	printerr("  FAILED ", path)
	return 1


func _ground_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(MAT_DIR + "ground.gdshader")
	m.set_shader_parameter("color_a", Color(0.36, 0.56, 0.22))
	m.set_shader_parameter("color_b", Color(0.20, 0.38, 0.14))
	m.set_shader_parameter("use_texture", false)
	m.set_shader_parameter("use_patches", true)
	m.set_shader_parameter("patch_scale", 12.0)
	m.set_shader_parameter("patch_amount", 0.5)
	m.set_shader_parameter("patch_softness", 0.18)
	m.set_shader_parameter("patch_detail", 0.35)
	m.set_shader_parameter("patch_warp", 0.25)
	return m


# --- Scene ----------------------------------------------------------------


func _flora_scene() -> PackedScene:
	var root := Node3D.new()
	root.name = "FloraPatch"
	root.set_script(load("res://scenes/props/flora_patch.gd"))
	root.set("patch_size", PATCH)
	root.set("ground_material", load(MAT_DIR + "ground.tres"))
	root.set("elements", _default_elements())

	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = PATCH
	ground.mesh = plane
	ground.material_override = load(MAT_DIR + "ground.tres")
	root.add_child(ground)
	ground.owner = root

	# Container the @tool script fills with the scatter layers (not saved).
	var flora := Node3D.new()
	flora.name = "Flora"
	flora.position = Vector3(0, 0.01, 0)
	root.add_child(flora)
	flora.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	return packed


func _default_elements() -> Array[FloraElement]:
	var thin := _blades(Color(0.20, 0.42, 0.14), Color(0.55, 0.78, 0.30), 7, 0.10)
	var broad := _blades(Color(0.16, 0.34, 0.12), Color(0.40, 0.62, 0.22), 4, 0.16)
	var f_white := _flower(Color(0.97, 0.97, 0.92), Color(0.98, 0.82, 0.25))
	var f_yellow := _flower(Color(0.98, 0.80, 0.20), Color(0.85, 0.55, 0.10))
	var f_red := _flower(Color(0.90, 0.35, 0.32), Color(0.98, 0.82, 0.25))
	var out: Array[FloraElement] = []
	out.append(_element("Grass (thin)", thin, 320, 0.34, 0.42, 0.18))
	out.append(_element("Grass (broad)", broad, 200, 0.40, 0.34, 0.14))
	out.append(_element("Flower (white)", f_white, 36, 0.28, 0.42, 0.10))
	out.append(_element("Flower (yellow)", f_yellow, 28, 0.28, 0.42, 0.10))
	out.append(_element("Flower (red)", f_red, 22, 0.28, 0.42, 0.10))
	return out


func _element(
	name: String, tex: Array, count: int, w: float, h: float, sway: float
) -> FloraElement:
	var e := FloraElement.new()
	e.element_name = name
	e.color_texture = tex[0]
	e.mask_texture = tex[1]
	e.count = count
	e.width = w
	e.height = h
	e.size_min = 0.8
	e.size_max = 1.3
	e.sway = sway
	return e


# --- Placeholder sprite generation (colour + mask) ------------------------


## A cluster of tapering blades. Returns [color_texture, mask_texture].
func _blades(base_col: Color, tip_col: Color, blade_count: int, spread: float) -> Array:
	var col := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	var mask := Image.create(TEX, TEX, false, Image.FORMAT_L8)
	col.fill(Color(0, 0, 0, 0))
	mask.fill(Color(0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(base_col.r * 1000.0) + blade_count
	for b in blade_count:
		var base_x := 0.5 + rng.randf_range(-0.28, 0.28)
		var tip_x := base_x + rng.randf_range(-spread, spread)
		var base_hw := rng.randf_range(0.03, 0.055)
		var top := rng.randf_range(0.08, 0.22)  # how high this blade reaches (v)
		for py in TEX:
			var v := float(py) / float(TEX - 1)  # 0 top .. 1 bottom
			if v < top or v > 0.99:
				continue
			var t := (1.0 - v)  # 0 at base .. 1 near top
			var cx := lerpf(base_x, tip_x, t)
			var hw := base_hw * (1.0 - (v - top) / (1.0 - top))  # wide at base → point
			for px in TEX:
				var u := float(px) / float(TEX - 1)
				if absf(u - cx) <= hw:
					col.set_pixel(px, py, base_col.lerp(tip_col, t))
					mask.set_pixel(px, py, Color(1, 1, 1))
	return [ImageTexture.create_from_image(col), ImageTexture.create_from_image(mask)]


## A simple stemmed flower: five petals + a centre. Returns [color_texture, mask_texture].
func _flower(petal_col: Color, center_col: Color) -> Array:
	var col := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	var mask := Image.create(TEX, TEX, false, Image.FORMAT_L8)
	col.fill(Color(0, 0, 0, 0))
	mask.fill(Color(0, 0, 0))
	var stem_col := Color(0.24, 0.44, 0.16)
	var center := Vector2(0.5, 0.30)
	var petals: Array[Vector2] = []
	for k in 5:
		var a := float(k) / 5.0 * TAU - PI * 0.5
		petals.append(center + Vector2(cos(a), sin(a)) * 0.17)
	for py in TEX:
		var v := float(py) / float(TEX - 1)
		for px in TEX:
			var u := float(px) / float(TEX - 1)
			var p := Vector2(u, v)
			var hit := false
			var out := Color(0, 0, 0, 0)
			if absf(u - 0.5) < 0.02 and v > 0.40 and v < 0.98:
				out = stem_col
				hit = true
			for pc in petals:
				if p.distance_to(pc) < 0.12:
					out = petal_col
					hit = true
			if p.distance_to(center) < 0.075:
				out = center_col
				hit = true
			if hit:
				col.set_pixel(px, py, out)
				mask.set_pixel(px, py, Color(1, 1, 1))
	return [ImageTexture.create_from_image(col), ImageTexture.create_from_image(mask)]
