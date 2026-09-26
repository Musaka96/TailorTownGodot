extends SceneTree

## Sheet for the pince-nez cut along the owner's seams (tripo_glasses.py's temple marker,
## GlassesFit._drop_temples). Top rows, one per style: the frames alone, framed tight,
## tinted red where the marker says temple, then the same frames cut (temples dropped) from
## the front, the side and behind (the end pieces). A style with no seams shows the
## hinge-plane fallback. Then Dr. Vance (head 3, rims shrunk) and Mr. Hemming (rims kept)
## at 0, 45 and 90 degrees, "before" = the old hinge-plane cut (the part's vertex colour
## stripped), "after" = the live fit. Prints, per style, the triangles the cut keeps and
## the pieces they form (a stray triangle shows as an extra piece). NOT headless:
##   godot --path . --script res://tools/shot_glasses_seams.gd
## Writes IMPORT/faces_proc/glasses_seams.png (git-ignored).

const CUSTOMER_SCENE := "res://entities/customer/customer.tscn"
const RIG_SCENE := "res://entities/character/character_rig.tscn"
const MANAGER_SCRIPT := "res://entities/customer/customer_manager.gd"
const PREF_SCRIPT := "res://data/scripts/customer_preference.gd"
const MENTOR_SCRIPT := "res://ui/tutorial/mentor_dialog.gd"
const STYLES := ["round", "square", "wire", "halfmoon"]
const VANCE_HEAD := 3
const ANGLES := [0.0, 45.0, 90.0]
## Frames-alone views: [tinted marker?, yaw degrees (0 = from the front), framing: 0 the
## whole part, 1 what the cut keeps, 2 the +x end piece at END_ZOOM].
const VIEWS := [
	[true, 35.0, 0], [true, 90.0, 0], [false, 35.0, 1], [false, 60.0, 2], [false, 150.0, 2]
]
const END_ZOOM := 3.0
const OUT_DIR := "res://IMPORT/faces_proc"
const SIZE := Vector2i(700, 700)
const CELL := 300
const LABEL_H := 40
const DIST := 0.8
const WELD := 1e-4
const PAPER := Color("f7f1e6")
const INK := Color("3a2418")
const TINT_CODE := """
shader_type spatial;
render_mode cull_disabled;
uniform bool tint = true;
void fragment() {
	float t = tint ? COLOR.r : 0.0;
	ALBEDO = mix(vec3(0.72, 0.72, 0.76), vec3(0.95, 0.18, 0.1), t);
	ROUGHNESS = 0.8;
}
"""

var _vp: SubViewport
var _world: Node3D
var _cam: Camera3D
var _stripped := {}


func _initialize() -> void:
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.55, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 0.95)
	env.ambient_light_energy = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -32, 0)
	_world.add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 35
	_world.add_child(_cam)
	_cam.current = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_run.call_deferred()


func _run() -> void:
	var cells := []
	var y := 0
	for style: String in STYLES:
		y = await _style_row(style, cells, y)
	_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	y = await _vance(cells, y)
	y = await _hemming(cells, y)
	await _save_grid(cells, Vector2i(CELL * VIEWS.size(), y), "glasses_seams.png")
	quit(0)


## One style's frames alone: tinted by the marker, then cut, from VIEWS.
func _style_row(style: String, cells: Array, y: int) -> int:
	var part := Wardrobe.library().glasses_part(style)
	var inst := part.model.instantiate()
	var src := inst.find_child(part.roles["frames"], true, false) as MeshInstance3D
	var bind := _bind(src)
	var mesh := src.mesh
	inst.free()
	var lens := GlassesFit.measure(mesh, bind)
	var cut := GlassesFit._build(mesh, bind, lens, lens.c, 1.0, true)
	var seams := _has_marker(mesh)
	_report(style, mesh, cut, seams)
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = TINT_CODE
	var mi := MeshInstance3D.new()
	mi.transform = bind
	mi.material_override = mat
	_world.add_child(mi)
	var how := "seam cut" if seams else "NO SEAMS: hinge-plane cut"
	var kept := _kept_box(cut, bind)
	var end := AABB(Vector3(kept.end.x, kept.get_center().y, kept.get_center().z), Vector3.ZERO)
	end = end.grow(kept.size.length() * 0.5 / END_ZOOM)
	for v in VIEWS.size():
		var tinted: bool = VIEWS[v][0]
		mi.mesh = mesh if tinted else cut
		mat.set_shader_parameter("tint", tinted and seams)
		var what := "temple marker (red)" if seams else "no marker"
		var label := "%s, %s, %d deg" % [style, what if tinted else how, VIEWS[v][1]]
		if VIEWS[v][2] == 2:
			label += ", +x end x%d" % END_ZOOM
		var box: AABB = [bind * mesh.get_aabb(), kept, end][VIEWS[v][2]]
		cells.append([await _frame_shot(box, VIEWS[v][1]), Vector2i(v * CELL, y), label])
	mi.queue_free()
	return y + CELL + LABEL_H


## Dr. Vance on head 3 (rims shrunk: a pince-nez), before and after.
func _vance(cells: Array, y: int) -> int:
	var manager: Node = load(MANAGER_SCRIPT).new()
	var cust: Node3D = (load(CUSTOMER_SCENE) as PackedScene).instantiate()
	_world.add_child(cust)
	cust.set_physics_process(false)
	cust.preference = load(PREF_SCRIPT).random_pref(RandomNumberGenerator.new(), "Dr. Vance")
	manager.call("_dress", cust)
	manager.free()
	cust.call("set_hair", VANCE_HEAD)
	var rig: Node = cust.get_node("Rig")
	rig.call("set_head", VANCE_HEAD)
	await _frames(3)
	y = await _turns(cust, rig, "Dr. Vance (head %d)" % VANCE_HEAD, cells, y)
	cust.queue_free()
	return y


## Mr. Hemming as the tutorial dresses him (rims at full size, temples kept).
func _hemming(cells: Array, y: int) -> int:
	var mentor: Node = load(MENTOR_SCRIPT).new()
	var look: Dictionary = mentor.call("_look")
	mentor.free()
	var rig: Node3D = (load(RIG_SCENE) as PackedScene).instantiate()
	_world.add_child(rig)
	rig.call("set_head", int(look.get("head", 0)))
	rig.call("set_hair", int(look.get("hair", 0)))
	rig.call("set_palette", look["skin"])
	rig.call("set_hair_color", look["hair_color"])
	rig.call("set_face_look", "brown", str(look.get("glasses", "")))
	rig.set("face_style", FaceCast.style(str(look.get("face_style", ""))))
	await _frames(3)
	y = await _turns(rig, rig, "Mr. Hemming", cells, y)
	rig.queue_free()
	return y


func _turns(body: Node3D, rig: Node, who: String, cells: Array, y: int) -> int:
	for after in [false, true]:
		for a in ANGLES.size():
			body.rotation_degrees.y = ANGLES[a]
			_fit(rig, after)
			var tag := "after (seam cut)" if after else "before (hinge-plane cut)"
			var label := "%s %d deg, %s" % [who, ANGLES[a], tag]
			cells.append([await _close_up(rig), Vector2i(a * CELL, y), label])
		y += CELL + LABEL_H
	body.rotation_degrees.y = 0.0
	return y


## after = the live fit; before = the same fit on the part with its marker stripped (the
## hinge-plane fallback).
func _fit(rig: Node, after: bool) -> void:
	rig.call("_place_glasses")
	if after:
		return
	var style: FaceStyle = rig.get("face_style")
	var frame: FaceFrame = rig.get("_face_frame")
	for mi: MeshInstance3D in rig.get("_glasses_meshes"):
		var src: Mesh = mi.get_meta("src")
		if not _stripped.has(src):
			_stripped[src] = _strip(src)
		mi.mesh = GlassesFit.fit(_stripped[src], mi.get_meta("bind"), style, frame)


## A copy of `src` without vertex colour.
func _strip(src: Mesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		arrays[Mesh.ARRAY_COLOR] = null
		var flags: int = src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(src.surface_get_primitive_type(s), arrays, [], {}, flags)
		out.surface_set_material(s, src.surface_get_material(s))
	return out


func _has_marker(mesh: Mesh) -> bool:
	for s in mesh.get_surface_count():
		if mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR] != null:
			return true
	return false


## Prints the triangles the cut keeps and the pieces (joined through shared corners,
## welded by position) they make: one piece = no stray triangle.
func _report(style: String, mesh: Mesh, cut: Mesh, seams: bool) -> void:
	var before := 0
	for s in mesh.get_surface_count():
		before += _tris(mesh.surface_get_arrays(s)).size() / 3
	var pieces := []
	var kept := 0
	for s in cut.get_surface_count():
		var arrays := cut.surface_get_arrays(s)
		var tris := _tris(arrays)
		kept += tris.size() / 3
		pieces.append_array(_pieces(arrays[Mesh.ARRAY_VERTEX], tris))
	print(
		(
			"%s: %s, %d of %d triangles kept, pieces (triangles each): %s"
			% [style, "seam marker" if seams else "no marker", kept, before, pieces]
		)
	)


func _tris(arrays: Array) -> PackedInt32Array:
	if arrays[Mesh.ARRAY_INDEX] != null:
		return arrays[Mesh.ARRAY_INDEX]
	var out := PackedInt32Array()
	for i in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
		out.append(i)
	return out


## Sizes (in triangles) of the connected pieces, largest first.
func _pieces(verts: PackedVector3Array, tris: PackedInt32Array) -> Array:
	var weld := {}
	var parent := PackedInt32Array()
	var ids := PackedInt32Array()
	for v in verts:
		var key := Vector3i((v / WELD).round())
		if not weld.has(key):
			weld[key] = weld.size()
			parent.append(weld.size() - 1)
		ids.append(weld[key])
	for t in range(0, tris.size() - 2, 3):
		var a := _root(parent, ids[tris[t]])
		for k in [1, 2]:
			var b := _root(parent, ids[tris[t + k]])
			if a != b:
				parent[b] = a
	var count := {}
	for t in range(0, tris.size() - 2, 3):
		var r := _root(parent, ids[tris[t]])
		count[r] = int(count.get(r, 0)) + 1
	var sizes: Array = count.values()
	sizes.sort()
	sizes.reverse()
	return sizes


func _root(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


## Mesh space -> head-bone space for a part's mesh (the rig's _head_bind, skin case).
func _bind(src: MeshInstance3D) -> Transform3D:
	if src.skin != null and src.skin.get_bind_count() > 0:
		for i in src.skin.get_bind_count():
			if String(src.skin.get_bind_name(i)) == "head":
				return src.skin.get_bind_pose(i)
		return src.skin.get_bind_pose(0)
	return src.transform


## Head-space box of the triangles `cut` keeps (its unused vertices stay in the arrays).
func _kept_box(cut: Mesh, bind: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	for s in cut.get_surface_count():
		var arrays := cut.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in _tris(arrays):
			var p := bind * verts[i]
			box = AABB(p, Vector3.ZERO) if first else box.expand(p)
			first = false
	return box


## The frames alone, orthographic, `box` (head space) filling the cell, seen from `yaw`
## degrees round y (0 = from the front, +z).
func _frame_shot(box: AABB, yaw: float) -> Image:
	var centre := box.get_center()
	var dir := Vector3(sin(deg_to_rad(yaw)), 0.15, cos(deg_to_rad(yaw))).normalized()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = box.size.length() * 0.8
	_cam.near = 0.01
	_cam.look_at_from_position(centre + dir * 2.0, centre, Vector3.UP)
	await _frames(4)
	var img := _vp.get_texture().get_image()
	img.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
	return img


## The rig's head seen from +z, centred on its glasses' front (the rims' centre).
func _close_up(rig: Node) -> Image:
	var blink: Timer = rig.get("_blink")
	if blink != null:
		blink.stop()
	await _frames(1)
	var at := (rig as Node3D).global_position + Vector3(0, 1.5, 0)
	var meshes: Array = rig.get("_glasses_meshes")
	if not meshes.is_empty():
		var mi: MeshInstance3D = meshes[0]
		var bind: Transform3D = mi.get_meta("bind")
		var lens := GlassesFit.measure(mi.get_meta("src"), bind)
		var front := Vector3(0.0, (lens.c as Vector2).y, lens.hinge)
		at = mi.global_transform * (bind.affine_inverse() * front)
	_cam.look_at_from_position(at + Vector3(0, 0, DIST), at, Vector3.UP)
	await _frames(4)
	var img := _vp.get_texture().get_image()
	var side := int(SIZE.x * 0.8)
	var crop := img.get_region(Rect2i((SIZE.x - side) / 2, (SIZE.y - side) / 2, side, side))
	crop.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
	return crop


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Lay out [image, top-left, label] cells on paper and save.
func _save_grid(cells: Array, size: Vector2i, file: String) -> void:
	var board := ColorRect.new()
	board.color = PAPER
	board.size = Vector2(size)
	for c: Array in cells:
		var pos := Vector2(c[1])
		var img: Image = c[0]
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(img)
		tr.position = pos
		board.add_child(tr)
		pos.y += img.get_height()
		var lab := Label.new()
		lab.text = c[2]
		lab.position = pos
		lab.size = Vector2(img.get_width(), LABEL_H)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD
		lab.add_theme_color_override("font_color", INK)
		lab.add_theme_font_size_override("font_size", 13)
		board.add_child(lab)
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(board)
	root.add_child(vp)
	await _frames(4)
	var path := OUT_DIR + "/" + file
	var err := vp.get_texture().get_image().save_png(path)
	vp.queue_free()
	print("Saved %s (%s)" % [path, error_string(err)])
