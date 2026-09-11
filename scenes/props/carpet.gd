@tool
extends Node3D

## The rug prop. The pile is REAL geometry: a curved, tapered tuft strand (built here with
## SurfaceTool) scattered thousands of times as a MultiMesh over the rug. Each tuft gets a
## random height, lean and facing, and takes its colour from the carpet pattern. A flat
## backing plane fills the gaps between strands.
##
## Everything below is a live control (edits rebuild the pile in the editor):
##   Rug Size, Density (tufts/m²), Pile Height + Height Variation, Bottom/Top Radius (taper),
##   Curve (how much strands bend), Lean (random tilt), Carpet Texture (the pattern colours).
## Base shading (depth) is on the Tufts node's Material Override.

const RADIAL := 5  # sides per strand
const RINGS := 3  # segments up each strand
const MAX_TUFTS := 60000

## The pattern the tufts are coloured from (and the backing shows). Swap it to re-skin the rug.
@export var carpet_texture: Texture2D:
	set(value):
		carpet_texture = value
		_rebuild()
@export var rug_size := Vector2(2.4, 1.6):
	set(value):
		rug_size = value
		_rebuild()
## Tufts per square metre — higher = denser (and more triangles).
@export var density := 800.0:
	set(value):
		density = maxf(value, 1.0)
		_rebuild()
@export var pile_height := 0.06:
	set(value):
		pile_height = maxf(value, 0.0)
		_rebuild()
@export_range(0.0, 1.0) var height_variation := 0.4:
	set(value):
		height_variation = value
		_rebuild()
@export var bottom_radius := 0.013:
	set(value):
		bottom_radius = maxf(value, 0.0001)
		_rebuild()
@export var top_radius := 0.004:
	set(value):
		top_radius = maxf(value, 0.0)
		_rebuild()
## Sideways bend of a strand from base to tip (metres), rotated a random way per tuft.
@export var curve := 0.02:
	set(value):
		curve = value
		_rebuild()
## Maximum random tilt of each strand, in degrees.
@export_range(0.0, 60.0) var lean := 12.0:
	set(value):
		lean = value
		_rebuild()
@export var scatter_seed := 99:
	set(value):
		scatter_seed = value
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	var backing := get_node_or_null("Backing") as MeshInstance3D
	var tufts := get_node_or_null("Tufts") as MultiMeshInstance3D
	if backing == null or tufts == null:
		return
	_update_backing(backing)
	_scatter(tufts)


func _update_backing(backing: MeshInstance3D) -> void:
	if not (backing.mesh is PlaneMesh):
		backing.mesh = PlaneMesh.new()
	(backing.mesh as PlaneMesh).size = rug_size
	if backing.material_override is StandardMaterial3D:
		(backing.material_override as StandardMaterial3D).albedo_texture = carpet_texture


func _scatter(tufts: MultiMeshInstance3D) -> void:
	if tufts.multimesh == null:
		tufts.multimesh = MultiMesh.new()
	var mm := tufts.multimesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _build_tuft_mesh()
	var area := rug_size.x * rug_size.y
	var count := clampi(int(area * density), 1, MAX_TUFTS)
	mm.instance_count = count
	var img := _pattern_image()
	var rng := RandomNumberGenerator.new()
	rng.seed = scatter_seed
	var hx := rug_size.x * 0.5
	var hz := rug_size.y * 0.5
	for i in count:
		var px := rng.randf_range(-hx, hx)
		var pz := rng.randf_range(-hz, hz)
		var hscale := pile_height * (1.0 - rng.randf() * height_variation)
		var yaw := rng.randf() * TAU
		var tilt := deg_to_rad(rng.randf_range(-lean, lean))
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3(1, 0, 0), tilt)
		basis = basis.scaled(Vector3(1.0, maxf(hscale, 0.0001), 1.0))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(px, 0.0, pz)))
		var u := px / rug_size.x + 0.5
		var v := pz / rug_size.y + 0.5
		mm.set_instance_color(i, _sample(img, u, v))


## One curved, tapered strand of unit height (scaled per instance). UV.y carries the height
## fraction so the shader can shade base→tip.
func _build_tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in RINGS:
		var h0 := float(ring) / float(RINGS)
		var h1 := float(ring + 1) / float(RINGS)
		var r0 := lerpf(bottom_radius, top_radius, h0)
		var r1 := lerpf(bottom_radius, top_radius, h1)
		var c0 := curve * h0 * h0  # bend grows toward the tip
		var c1 := curve * h1 * h1
		for seg in RADIAL:
			var a0 := float(seg) / float(RADIAL) * TAU
			var a1 := float(seg + 1) / float(RADIAL) * TAU
			var v00 := Vector3(c0 + r0 * cos(a0), h0, r0 * sin(a0))
			var v10 := Vector3(c0 + r0 * cos(a1), h0, r0 * sin(a1))
			var v01 := Vector3(c1 + r1 * cos(a0), h1, r1 * sin(a0))
			var v11 := Vector3(c1 + r1 * cos(a1), h1, r1 * sin(a1))
			_tri(st, v00, v10, v11, h0, h0, h1)
			_tri(st, v00, v11, v01, h0, h1, h1)
	st.generate_normals()
	return st.commit()


func _tri(
	st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ha: float, hb: float, hc: float
) -> void:
	st.set_uv(Vector2(0.0, ha))
	st.add_vertex(a)
	st.set_uv(Vector2(1.0, hb))
	st.add_vertex(b)
	st.set_uv(Vector2(1.0, hc))
	st.add_vertex(c)


func _pattern_image() -> Image:
	if carpet_texture == null:
		return null
	var img := carpet_texture.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	return img


func _sample(img: Image, u: float, v: float) -> Color:
	if img == null:
		return Color(0.6, 0.18, 0.2)
	var w := img.get_width()
	var h := img.get_height()
	var px := clampi(int(clampf(u, 0.0, 1.0) * float(w - 1)), 0, w - 1)
	var py := clampi(int(clampf(v, 0.0, 1.0) * float(h - 1)), 0, h - 1)
	return img.get_pixel(px, py)
