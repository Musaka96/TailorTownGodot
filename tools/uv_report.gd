extends SceneTree

## Checks the UV quality of the character's cloth meshes and draws their UV layouts to
## .dev/. Run it before and after touching the unwrap in Blender:
##   godot --headless --path . --script res://tools/uv_report.gd
## Another glb and/or mesh list (the layouts then go to .dev/uv_<glb name>_<mesh>_<n>.png):
##   godot --headless --path . --script res://tools/uv_report.gd --
##       --glb=res://assets/characters/CHARTGEN2.glb --meshes=jacket,shirt,legs,tie
##
## The garment materials tile a fabric across the mesh UVs (see materials/cloth.gdshader),
## so what matters is NOT a tidily packed atlas:
##   * STRETCH — the spread of texel density across the mesh. A pattern is only as
##     square as the unwrap is uniform; anything past ~1.5x visibly smears the weave.
##   * a sane UV area. Far below 100% wastes resolution; the layout may also be
##     collapsed, which smears one patch of cloth over a whole panel.
## Islands overlapping each other is fine here, because the fabric repeats.

const SRC := "res://assets/characters/CHARTGEN1.glb"
# The meshes that get a tiling fabric (ClothMaterial) rather than a flat colour or a
# baked texture — see entities/character/character_rig.gd.
const CLOTH_MESHES := ["jacket", "shirt", "legs"]
const STRETCH_WARN := 1.5
const IMG := 512
const OUT_DIR := "res://.dev"

var _src := SRC
var _prefix := ""


func _initialize() -> void:
	var meshes: Array = CLOTH_MESHES
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--glb="):
			_src = arg.trim_prefix("--glb=")
			_prefix = _src.get_file().get_basename() + "_"
		elif arg.begins_with("--meshes="):
			meshes = Array(arg.trim_prefix("--meshes=").split(","))
	if not DirAccess.dir_exists_absolute(OUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var scene := load(_src) as PackedScene
	if scene == null:
		push_error("could not load " + _src)
		quit(1)
		return
	print(_src)
	var instance := scene.instantiate()
	var worst := 1.0
	for name in meshes:
		var found := instance.find_children(name, "MeshInstance3D", true, false)
		if found.is_empty():
			print("%-8s MISSING from %s" % [name, _src])
			continue
		worst = maxf(worst, _report(name, (found[0] as MeshInstance3D).mesh))
	print("\nworst stretch %.2fx (the guide is under %.2fx)" % [worst, STRETCH_WARN])
	quit(0)


## Prints one mesh's UV stats, writes its layout to .dev/, and returns its stretch.
func _report(name: String, mesh: Mesh) -> float:
	if mesh == null:
		print("%-8s has no mesh" % name)
		return 1.0
	var worst := 1.0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if arrays[Mesh.ARRAY_TEX_UV] == null:
			print("%-8s surf%d: %d verts, NO UVs at all" % [name, s, verts.size()])
			continue
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var stretch := _surface(name, s, verts, uv, indices)
		worst = maxf(worst, stretch)
		_draw(name, s, uv, indices)
	return worst


func _surface(
	name: String,
	surf: int,
	verts: PackedVector3Array,
	uv: PackedVector2Array,
	indices: PackedInt32Array
) -> float:
	var lo := Vector2(INF, INF)
	var hi := -lo
	for u in uv:
		lo = lo.min(u)
		hi = hi.max(u)

	# Texel density per triangle = UV edge length per unit of surface length.
	var density := PackedFloat32Array()
	var uv_area := 0.0
	var tris: int = indices.size() / 3
	for t in tris:
		var i0 := indices[t * 3]
		var i1 := indices[t * 3 + 1]
		var i2 := indices[t * 3 + 2]
		var area: float = (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0]).length() * 0.5
		var e1 := uv[i1] - uv[i0]
		var e2 := uv[i2] - uv[i0]
		var flat: float = absf(e1.x * e2.y - e1.y * e2.x) * 0.5
		uv_area += flat
		if area > 1e-9 and flat > 1e-12:
			density.append(sqrt(flat / area))
	if density.is_empty():
		print("%-8s surf%d: no usable triangles" % [name, surf])
		return 1.0

	# Percentiles rather than min/max, so one degenerate triangle doesn't set the tone.
	density.sort()
	var low: float = density[int(density.size() * 0.05)]
	var high: float = density[int(density.size() * 0.95)]
	var stretch: float = high / maxf(low, 1e-6)
	print(
		(
			"%-8s surf%d: %5d verts %5d tris | UV %.2f,%.2f..%.2f,%.2f | area %5.1f%% | stretch %4.2fx  %s"
			% [
				name,
				surf,
				verts.size(),
				tris,
				lo.x,
				lo.y,
				hi.x,
				hi.y,
				uv_area * 100.0,
				stretch,
				"ok" if stretch <= STRETCH_WARN else "SMEARS"
			]
		)
	)
	return stretch


## Wireframe of the UV triangles, so a collapsed or tangled island is obvious.
func _draw(name: String, surf: int, uv: PackedVector2Array, indices: PackedInt32Array) -> void:
	var img := Image.create(IMG, IMG, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.08, 0.08, 0.1))
	for t in indices.size() / 3:
		for e in 3:
			_line(img, uv[indices[t * 3 + e]], uv[indices[t * 3 + (e + 1) % 3]])
	var path := "%s/uv_%s%s_%d.png" % [OUT_DIR, _prefix, name, surf]
	if img.save_png(path) != OK:
		push_error("save failed: " + path)


## Additive so overlapping triangles show up bright — that's the tangle to look for.
func _line(img: Image, a: Vector2, b: Vector2) -> void:
	var pa := Vector2(a.x * IMG, a.y * IMG)
	var pb := Vector2(b.x * IMG, b.y * IMG)
	var steps: int = int(maxf(pa.distance_to(pb), 1.0))
	for i in steps + 1:
		var p: Vector2 = pa.lerp(pb, float(i) / steps)
		var x: int = int(p.x)
		var y: int = int(p.y)
		if x < 0 or y < 0 or x >= IMG or y >= IMG:
			continue
		var c := img.get_pixel(x, y)
		img.set_pixel(x, y, Color(minf(c.r + 0.25, 1.0), minf(c.g + 0.5, 1.0), 0.35))
