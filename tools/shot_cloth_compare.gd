extends SceneTree

## A/B comparison sheets for cloth-look changes: the 5 suiting fabrics on the real
## garment meshes (instanced straight from the glb — set_outfit doesn't apply cloth
## in a bare --script run), rendered rim-OFF then rim-ON under three setups, each
## pair stacked into one PNG in .dev/. NOT headless:
##   godot --path . --script res://tools/shot_cloth_compare.gd

const GLB := "res://assets/characters/CHARTGEN1.glb"
const NAVY := Color(0.13, 0.17, 0.28)
const FABRICS := [0, 1, 2, 3, 4]  # worsted, flannel, tweed, mohair, linen
const FABRIC_NAMES := ["Worsted", "Flannel", "Tweed", "Mohair", "Linen"]
const SPACING := 2.3
const SETUPS := [
	["front", Vector3(-38, -32, 0), Vector3(0, 1.2, 9.5), Vector3(0, 1.0, 0), 35.0],
	["raking", Vector3(-10, -75, 0), Vector3(0, 1.2, 9.5), Vector3(0, 1.0, 0), 35.0],
	# The real camera-rig position (pitch −55°, 7.7 m) with a narrow fov as a crop-zoom,
	# so the foreshortening matches the game while the suits stay big enough to judge.
	["gameplay", Vector3(-38, -32, 0), Vector3(0, 6.27, 4.39), Vector3(0, 0.9, 0), 28.0],
]

var _world: Node3D
var _sun: DirectionalLight3D
var _cam: Camera3D
var _labels: CanvasLayer
var _row_label: Label
var _col_labels: Array[Label] = []
var _cloth: Array[ShaderMaterial] = []
var _figs: Array[Node3D] = []
var _base_live: ShaderMaterial
var _shots: Array[Image] = []
var _setup := 0
var _rim_on := false
var _phase := 0  # 0 = stacked lineup pairs, 1 = Tier 1 close-up, 2 = Tier 2 close-up
var _frames := 0


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	_world = Node3D.new()
	root.add_child(_world)
	_hide_overlays()
	_add_environment()
	_add_figures()
	_apply_setup()
	process_frame.connect(_on_frame)


## The game's autoloads draw their HUD / paper-grain post-FX over everything —
## hide every CanvasLayer (except our own labels) so the sheet shows only the cloth.
func _hide_overlays() -> void:
	for child in root.get_children():
		for layer: Node in child.find_children("*", "CanvasLayer", true, false):
			if layer != _labels:
				(layer as CanvasLayer).visible = false
		if child is CanvasLayer and child != _labels:
			(child as CanvasLayer).visible = false


func _add_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.33, 0.36, 0.42)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 0.95)
	env.ambient_light_energy = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_world.add_child(_sun)
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor_mesh.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.42, 0.4, 0.38)
	fm.roughness = 1.0
	floor_mesh.material_override = fm
	_world.add_child(floor_mesh)
	_cam = Camera3D.new()
	_world.add_child(_cam)
	_cam.make_current()
	_labels = CanvasLayer.new()
	_labels.layer = 100
	root.add_child(_labels)
	_row_label = _label(Vector2(24, 16), 40, Color(1, 0.93, 0.6))
	for i in FABRICS.size():
		_col_labels.append(_label(Vector2.ZERO, 28, Color(0.97, 0.97, 0.97)))
		_col_labels[i].text = FABRIC_NAMES[i]


func _add_figures() -> void:
	var meshes := _garment_meshes()
	for i in FABRICS.size():
		var x := (i - 2.0) * SPACING
		var mat_type := MaterialType.new()
		mat_type.fabric = FABRICS[i]
		mat_type.pattern = 0  # solid — judge the fabric surface, not a motif
		mat_type.cloth_color = NAVY
		var cloth := ClothMaterial.build(mat_type, 6.0, true)
		_cloth.append(cloth)
		_figs.append(_figure(meshes, cloth, Vector3(x, 0, 0)))


func _figure(meshes: Dictionary, cloth: ShaderMaterial, pos: Vector3) -> Node3D:
	var fig := Node3D.new()
	fig.position = pos
	_world.add_child(fig)
	for mesh_name: String in ["jacket", "legs", "shirt"]:
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[mesh_name]
		if mesh_name == "shirt":
			var flat := StandardMaterial3D.new()
			flat.albedo_color = Color(0.92, 0.92, 0.9)
			flat.roughness = 1.0
			mi.material_override = flat
		else:
			mi.material_override = cloth
		fig.add_child(mi)
	return fig


## The garment Mesh resources straight out of the glb (bind pose when shown on a
## bare MeshInstance3D — good enough to judge fabric).
func _garment_meshes() -> Dictionary:
	var scene: Node = (load(GLB) as PackedScene).instantiate()
	var out := {}
	for mesh_name: String in ["jacket", "legs", "shirt"]:
		var mi := scene.find_child(mesh_name, true, false) as MeshInstance3D
		out[mesh_name] = mi.mesh
	scene.free()
	return out


func _label(pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = 8
	ls.outline_color = Color(0.08, 0.08, 0.1)
	l.label_settings = ls
	_labels.add_child(l)
	return l


func _apply_setup() -> void:
	var s: Array = SETUPS[_setup]
	_sun.rotation_degrees = s[1]
	_cam.fov = s[4]
	_cam.look_at_from_position(s[2], s[3], Vector3.UP)
	_row_label.text = "%s  —  Tier 1 %s" % [s[0], "ON" if _rim_on else "OFF"]
	for i in _cloth.size():
		_set_tier1(_cloth[i], FABRICS[i], _rim_on)
		var head := Vector3((i - 2.0) * SPACING, 2.0, 0)
		_col_labels[i].position = _cam.unproject_position(head) - Vector2(45, 0)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		_hide_overlays()  # again: some autoload UI spawns deferred
		if _phase == 0:
			_apply_setup()  # window size is settled now — fixes the label unprojection
	if _frames < 8:
		return
	_frames = 0
	var shot := get_root().get_texture().get_image()
	shot.convert(Image.FORMAT_RGBA8)
	if _phase == 1:
		shot.save_png("res://.dev/cloth_rim_closeup.png")
		print("Saved res://.dev/cloth_rim_closeup.png")
		_build_closeup2()
		return
	if _phase == 2:
		shot.save_png("res://.dev/cloth_tier2_closeup.png")
		print("Saved res://.dev/cloth_tier2_closeup.png")
		print("shot_cloth_compare: done.")
		quit(0)
		return
	_shots.append(shot)
	if not _rim_on:
		_rim_on = true
		_apply_setup()
		return
	_save_pair(SETUPS[_setup][0])
	_shots.clear()
	_rim_on = false
	_setup += 1
	if _setup < SETUPS.size():
		_apply_setup()
		return
	_build_closeup()


## Final sheet: worsted and mohair with rim off / ON side by side in ONE frame —
## identical lighting, adjacent, torso-height camera. The one to judge sheen by.
func _build_closeup() -> void:
	_phase = 1
	for fig in _figs:
		fig.queue_free()
	_figs.clear()
	_cloth.clear()
	var meshes := _garment_meshes()
	# Tweed shows the neps + weave normals, mohair the sheen; a lighter cloth than
	# navy so the normal-map shading actually has room to read.
	var cols: Array = [[2, false], [2, true], [3, false], [3, true]]
	var names: Array = ["Tweed  off", "Tweed  ON", "Mohair  off", "Mohair  ON"]
	for i in cols.size():
		var mat_type := MaterialType.new()
		mat_type.fabric = cols[i][0]
		mat_type.pattern = 0
		mat_type.cloth_color = Color(0.52, 0.47, 0.4) if cols[i][0] == 2 else NAVY
		var cloth := ClothMaterial.build(mat_type, 6.0, true)
		_set_tier1(cloth, cols[i][0], cols[i][1])
		_figs.append(_figure(meshes, cloth, _close_pos(i)))
		_col_labels[i].text = names[i]
	_col_labels[4].visible = false
	_row_label.text = "close-up  —  raking light"
	_sun.rotation_degrees = Vector3(-12, -70, 0)
	_cam.fov = 45
	_cam.look_at_from_position(Vector3(0, 1.35, 4.6), Vector3(0, 1.25, 0), Vector3.UP)
	for i in cols.size():
		var head := _close_pos(i) + Vector3(0, 2.0, 0)
		_col_labels[i].position = _cam.unproject_position(head) - Vector2(80, 0)


## Tier 2 sheet: the two-colour glen check next to its one-colour self, and shot
## end-on-end next to flat — same camera and raking light as the Tier 1 close-up.
func _build_closeup2() -> void:
	_phase = 2
	for fig in _figs:
		fig.queue_free()
	_figs.clear()
	var meshes := _garment_meshes()
	var names: Array = ["Glen 1-colour", "Glen 2-colour", "End-on-end flat", "End-on-end shot"]
	var cols: Array = [[5, false], [5, true], [13, false], [13, true]]
	for i in cols.size():
		var mat_type := MaterialType.new()
		mat_type.pattern = cols[i][0]
		var glen: bool = cols[i][0] == 5
		mat_type.fabric = 0 if glen else 6  # worsted glen check; poplin end-on-end
		mat_type.cloth_color = Color(0.72, 0.7, 0.66) if glen else Color(0.4, 0.5, 0.66)
		mat_type.pattern_color = Color(0.13, 0.13, 0.16) if glen else Color(0.9, 0.92, 0.95)
		var cloth := ClothMaterial.build(mat_type, 6.0, true)
		if not cols[i][1]:
			# The "old" side: overcheck in the same colour / no shot shimmer.
			if glen:
				cloth.set_shader_parameter("pattern_color2", mat_type.pattern_color)
			else:
				cloth.set_shader_parameter("shot_strength", 0.0)
		_figs.append(_figure(meshes, cloth, _close_pos(i)))
		_col_labels[i].text = names[i]
	_row_label.text = "Tier 2  —  two-colour glen check + shot end-on-end"
	for i in cols.size():
		var head := _close_pos(i) + Vector3(0, 2.0, 0)
		_col_labels[i].position = _cam.unproject_position(head) - Vector2(80, 0)


## Column spots for the close-up; neighbours stagger in z so T-pose arms don't
## intersect at this tight spacing.
func _close_pos(i: int) -> Vector3:
	return Vector3((i - 1.5) * 1.6, 0, -0.35 if i % 2 == 1 else 0.0)


## The whole Tier 1 bundle on or off: rim sheen (B1), weave normals (B2) and macro
## breakup (B4). Tweed's coloured neps (B3) are baked into the albedo texture and
## show on both sides. ON restores the live values from the base .tres.
func _set_tier1(cloth: ShaderMaterial, fabric: int, on: bool) -> void:
	cloth.set_shader_parameter("rim_strength", ClothMaterial.fabric_rim(fabric) if on else 0.0)
	cloth.set_shader_parameter("normal_depth", _live("normal_depth") if on else 0.0)
	cloth.set_shader_parameter("macro_strength", _live("macro_strength") if on else 0.0)


## A live global's value straight off the base material.
func _live(key: String) -> float:
	if _base_live == null:
		_base_live = load(ClothMaterial.BASE_PATH) as ShaderMaterial
	var v: Variant = _base_live.get_shader_parameter(key)
	return float(v) if v != null else 0.0


## Stack the OFF shot above the ON shot into one comparison sheet.
func _save_pair(setup_name: String) -> void:
	var a := _shots[0]
	var b := _shots[1]
	var sheet := Image.create(a.get_width(), a.get_height() * 2, false, Image.FORMAT_RGBA8)
	sheet.blit_rect(a, Rect2i(0, 0, a.get_width(), a.get_height()), Vector2i.ZERO)
	sheet.blit_rect(b, Rect2i(0, 0, b.get_width(), b.get_height()), Vector2i(0, a.get_height()))
	var path := "res://.dev/cloth_rim_%s.png" % setup_name
	sheet.save_png(path)
	print("Saved ", path)
