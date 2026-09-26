class_name GlassesFit
extends RefCounted

## Fits a pair of glasses (a Wardrobe glasses part's mesh) to a cut-paper face, the way
## an optician would rather than by stretching the frame: each rim moves rigidly across
## onto its eye, so a round lens stays round and its centre sits over the eye centre, and
## hangs GLASSES_HANG below it, resting on the nose as the frames did before the fit (owner,
## 2026-09-26: centred on the eyes they looked pinned on); a rim only grows (uniformly) when
## the eye's white would spill past it, and only shrinks when the eyes are too close for the
## rims to fit; the bridge stretches or shrinks between the rims; each temple rides its
## hinge and turns about it, rigidly, so its ear end points back where the part was
## modelled (a shear kinked the arm behind the rim), turning in no further than keeps the
## arm's widest point off the head.
##
## Everything is measured in head-bone space (x across, y up, z forward): the part's rims
## from its own mesh (measure()), the eyes from the FaceStyle and the head's FaceFrame, as
## skin_face.gdshader lays the face out (eye_point()).

## How far the lens centre hangs below the eye centre, metres. The frames as modelled (the
## placement before the fit) hung 0.044 (square), 0.052 (wire, round) and 0.038
## (half-moon) below J1's eye line; one value for every frame, the owner's dial.
const GLASSES_HANG := 0.045
## Rim clearance kept round an eye white (or a dot eye's pupil), metres.
const WHITE_MARGIN := 0.012
## A rim grows at most this much over the part's own size.
const MAX_GROW := 1.3
## Half the gap the bridge keeps between the rims at the least, metres.
const MIN_BRIDGE := 0.012
## Vertices this close (metres) above the lowest front vertex count as the rim's bottom.
const BOTTOM_BAND := 0.004
## The column round the lens centre whose height gives a full rim's size, metres.
const COLUMN := 0.015

static var _lens_cache := {}
static var _fit_cache := {}


## `src` fitted to `style` on the head whose face rect is `frame`, in the mesh's own space
## (`bind` takes it to head-bone space, as the rig's _head_bind). Cached per input.
static func fit(src: Mesh, bind: Transform3D, style: FaceStyle, frame: FaceFrame) -> Mesh:
	if src == null or style == null or frame == null:
		return src
	var lens := measure(src, bind)
	if lens.is_empty():
		return src
	var eye := eye_point(style, frame)
	var grow := rim_grow(lens, eye.x, eye_radius(style, frame))
	var at := Vector2(eye.x, eye.y - GLASSES_HANG)  # where the lens centre goes
	var key := "%d|%s|%.4f|%.4f|%.4f" % [src.get_instance_id(), bind, at.x, at.y, grow]
	if not _fit_cache.has(key):
		_fit_cache[key] = _build(src, bind, lens, at, grow)
	return _fit_cache[key]


## The +x eye's centre in head-bone space (metres): the face-unit spot the shader draws it
## at (eye_spacing across, eye_height down the disc, or the head's own eye_line), through
## the face rect's mapping (face_scale, face_drop and the frame's nudges apply).
static func eye_point(style: FaceStyle, frame: FaceFrame) -> Vector2:
	var ds := FaceStyle.DISC_SCALE * FaceStyle.face_scale
	var fy := frame.eye_line
	if fy < 0.0:
		var dcv := FaceStyle.DISC_CENTER_V + FaceStyle.face_drop
		fy = dcv + (style.eye_height - 0.5) * FaceStyle.LAYOUT_ASPECT * ds
	var v := (fy - 0.5) * frame.scale + 0.5 + frame.offset.y
	var x := style.eye_spacing * ds * frame.scale * frame.size.x
	return Vector2(x, frame.center.y - (v - 0.5) * frame.size.y)


## The eye's reach from its centre (metres): its white's larger radius, or the pupil on a
## dot eye. Sizes follow the rect width, as in the shader.
static func eye_radius(style: FaceStyle, frame: FaceFrame) -> float:
	var r := style.white_radius * maxf(1.0, style.white_aspect)
	if style.white_radius <= 1e-3:
		r = style.pupil_radius
	return r * FaceStyle.DISC_SCALE * FaceStyle.face_scale * frame.scale * frame.size.x


## How much the rims scale about their centres: 1 unless the eye needs more room (up to
## MAX_GROW), and never so big that the rims close the bridge (the only case that shrinks).
static func rim_grow(lens: Dictionary, eye_x: float, eye_r: float) -> float:
	var r: float = lens.r
	var grow := clampf((eye_r + WHITE_MARGIN) / r, 1.0, MAX_GROW)
	return minf(grow, maxf(eye_x - MIN_BRIDGE, 0.2 * r) / r)


## The part's +x rim in head-bone space, cached per mesh: {c: lens centre (x, y), r: its
## inner reach (centre to the rim's innermost x), x_in: that innermost x, hinge: the plane
## (z) between the front and the temples, and per side (1, -1) its temple (_temple())}.
## {} when the mesh has no front.
static func measure(src: Mesh, bind: Transform3D) -> Dictionary:
	var key := "%d|%s" % [src.get_instance_id(), bind]
	if _lens_cache.has(key):
		return _lens_cache[key]
	var pts := PackedVector3Array()
	for s in src.get_surface_count():
		for v: Vector3 in src.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			pts.append(bind * v)
	var out := _measure_front(pts)
	if not out.is_empty():
		for side: float in [1.0, -1.0]:
			out[side] = _temple(pts, out.hinge, side)
	_lens_cache[key] = out
	return out


## The front of the frame (in front of the hinge plane, as tripo_glasses.py's _hinge_y):
## the rim's bottom point gives the lens centre's x; a full rim's height at that x, or a
## half-rim's width (a half-moon is the lower half of its circle), gives its y.
static func _measure_front(pts: PackedVector3Array) -> Dictionary:
	var xmax := 0.0
	var zmax := -INF
	for p in pts:
		xmax = maxf(xmax, absf(p.x))
		zmax = maxf(zmax, p.z)
	var rim_back := INF
	for p in pts:
		if absf(p.x) < 0.5 * xmax:  # the rims, never a temple (the square's hook inward)
			rim_back = minf(rim_back, p.z)
	var hinge := rim_back - 0.5 * (zmax - rim_back)
	var front := PackedVector3Array()
	for p in pts:
		if p.z > hinge and p.x > 0.0:
			front.append(p)
	if front.size() < 8:
		return {}
	var yb := INF
	var bridge_low := INF
	for p in front:
		yb = minf(yb, p.y)
		if p.x < 0.01:
			bridge_low = minf(bridge_low, p.y)
	var cx := _mean_x(front, yb + BOTTOM_BAND)
	var ytop := yb
	var x_in := cx
	for p in front:
		if absf(p.x - cx) < COLUMN:
			ytop = maxf(ytop, p.y)
		if p.y < bridge_low - 0.005:
			x_in = minf(x_in, p.x)
	var r := maxf(cx - x_in, 0.02)
	var cy := yb + (ytop - yb) * 0.5 if ytop - yb >= 1.2 * r else yb + r  # square: 1.33 r
	return {"c": Vector2(cx, cy), "r": r, "x_in": cx - r, "hinge": hinge}


static func _mean_x(front: PackedVector3Array, below: float) -> float:
	var sum := 0.0
	var n := 0
	for p in front:
		if p.y <= below:
			sum += p.x
			n += 1
	return sum / maxf(n, 1)


## One temple (behind the hinge plane on `side`): {tip: its furthest-back z, near: the
## centre of its first tenth behind the hinge, end: the centre of its last tenth (the ear
## end), wide: its widest point (over the side of the head)}, or {} when the side has none.
static func _temple(pts: PackedVector3Array, hinge: float, side: float) -> Dictionary:
	var tip := INF
	var wide := Vector3.ZERO
	for p in pts:
		if p.z <= hinge and p.x * side > 0.0:
			tip = minf(tip, p.z)
			if absf(p.x) > absf(wide.x):
				wide = p
	if tip == INF:
		return {}
	var tenth := 0.1 * (hinge - tip)
	var near := Vector3.ZERO
	var end := Vector3.ZERO
	var n := Vector2.ZERO
	for p in pts:
		if p.z <= hinge and p.x * side > 0.0:
			if p.z > hinge - tenth:
				near += p
				n.x += 1
			elif p.z < tip + tenth:
				end += p
				n.y += 1
	return {"tip": tip, "near": near / maxf(n.x, 1), "end": end / maxf(n.y, 1), "wide": wide}


static func _build(
	src: Mesh, bind: Transform3D, lens: Dictionary, eye: Vector2, grow: float
) -> ArrayMesh:
	var inv := bind.affine_inverse()
	var arms := {}
	for side: float in [1.0, -1.0]:
		arms[side] = temple_move(lens, eye, grow, side)
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i] = inv * _move(bind * verts[i], lens, eye, grow, arms)
		arrays[Mesh.ARRAY_VERTEX] = verts
		var flags: int = src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(src.surface_get_primitive_type(s), arrays, [], {}, flags)
		out.surface_set_material(s, src.surface_get_material(s))
	return out


## One temple's rigid move (head space) for a fit that puts the lens centre at `eye`: it
## rides its hinge (the front's move of the temple's near end), then turns about the moved
## hinge so its ear end points back where it was modelled: a yaw, then the small pitch that
## matches the end's height. The yaw turns in no further than keeps the temple's widest
## point at its modelled x (further in, the arm would cut into the head); the ear end then
## sits a touch wider. Identity for a side with no temple.
static func temple_move(lens: Dictionary, eye: Vector2, grow: float, side: float) -> Transform3D:
	var temple: Dictionary = lens.get(side, {})
	if temple.is_empty():
		return Transform3D.IDENTITY
	var near: Vector3 = temple.near
	var hinge := _front(near, lens, eye, grow)
	var v: Vector3 = temple.end - near  # the arm as it rides the hinge
	var u: Vector3 = temple.end - hinge  # where its end should be
	# the yaw in the side's mirrored frame (x outward): > 0 swings the arm's end inward
	var yaw := atan2(u.x * side, u.z) - atan2(v.x * side, v.z)
	var w: Vector3 = temple.wide - near
	var reach := Vector2(w.x * side, w.z).length()
	var k: float = (temple.wide.x - hinge.x) * side
	if reach > 1e-4 and absf(k) <= reach:
		var a := atan2(w.z, w.x * side)
		var off := acos(k / reach)
		yaw = minf(yaw, a - off if absf(a - off) < absf(a + off) else a + off)
	var turn := Basis(Vector3.UP, yaw * side)
	var arm := turn * v
	var target := Vector3(arm.x, u.y, arm.z)
	var axis := arm.cross(target)
	if axis.length() > 1e-6:
		turn = Basis(axis.normalized(), arm.angle_to(target)) * turn
	return Transform3D(turn, hinge) * Transform3D(Basis.IDENTITY, -near)


## One head-space point, fitted. Front: a rim point maps rigidly (scaled by `grow`) from
## the lens centre to `eye`; a bridge point (inside the rims) scales across to the new
## inner edge and follows the rims up or down. Temple: its side's rigid move (`arms`,
## temple_move()).
static func _move(
	p: Vector3, lens: Dictionary, eye: Vector2, grow: float, arms: Dictionary
) -> Vector3:
	if p.z <= lens.hinge:
		var arm: Transform3D = arms[1.0 if p.x > 0.0 else -1.0]
		return arm * p
	return _front(p, lens, eye, grow)


static func _front(p: Vector3, lens: Dictionary, eye: Vector2, grow: float) -> Vector3:
	var c: Vector2 = lens.c
	var x_in: float = lens.x_in
	var y := eye.y + grow * (p.y - c.y)
	var ax := absf(p.x)
	if ax < x_in:
		return Vector3(p.x * (eye.x - grow * (c.x - x_in)) / x_in, y, p.z)
	return Vector3(signf(p.x) * (eye.x + grow * (ax - c.x)), y, p.z)
