class_name FaceLayout
extends Resource

## Placement of the 2D face elements on a character's head — the single source the
## rig reads at runtime and the Face Editor dock writes. All distances are in metres
## in the head's local space (y is up, relative to the head centre; x is offset from
## the midline). "gap" is the centre-to-centre distance between the paired left/right
## elements, so it directly controls how far apart the eyes / brows sit. "px" is the
## sprite's pixel_size (metres per texture pixel), i.e. how big that element draws.
## Stored at res://data/face_layout.tres.

const PATH := "res://data/face_layout.tres"

## How far the whole face sits in front of the head, and the head-centre height.
## Deeper head meshes need the face pushed further out, so face_z can be overridden
## per head index in head_face_z (falling back to face_z when a head has no entry).
@export var face_z := 0.47
@export var head_y := 1.64
## head index -> face_z override. Tune per head in the char preview (edit face_z),
## which writes the current head's entry here.
@export var head_face_z: Dictionary = {}

## Each element also has an `_x` (horizontal midline offset, metres; + = the character's
## left/screen-right) and an `_curve` (extra wrap added to face_curve just for that element).
## `_rot` is a Vector3 of euler DEGREES (pitch x / yaw y / roll z) and `_scale` a Vector3
## multiplier on the sprite (x = width, y = height; z is unused for the flat sprite). Paired
## elements (eyes/brows) mirror yaw+roll and share pitch/scale. All default to no change.

@export_group("Eyes")
@export var eye_y := 0.09
@export var eye_gap := 0.16
@export var eye_px := 0.0060
@export var eye_x := 0.0
@export var eye_curve := 0.0
@export var eye_rot := Vector3.ZERO
@export var eye_scale := Vector3.ONE

@export_group("Brows")
@export var brow_y := 0.155
@export var brow_gap := 0.17
@export var brow_px := 0.0060
@export var brow_x := 0.0
@export var brow_curve := 0.0
@export var brow_rot := Vector3.ZERO
@export var brow_scale := Vector3.ONE

@export_group("Nose")
@export var nose_y := -0.03
@export var nose_px := 0.0050
@export var nose_x := 0.0
@export var nose_curve := 0.0
@export var nose_rot := Vector3.ZERO
@export var nose_scale := Vector3.ONE

@export_group("Mouth")
@export var mouth_y := -0.13
@export var mouth_px := 0.0060
@export var mouth_x := 0.0
@export var mouth_curve := 0.0
@export var mouth_rot := Vector3.ZERO
@export var mouth_scale := Vector3.ONE

@export_group("Glasses")
## Glasses sit centred over the eyes; a single wide sprite (not paired).
@export var glasses_y := 0.085
@export var glasses_px := 0.0036
@export var glasses_x := 0.0
@export var glasses_curve := 0.0
@export var glasses_rot := Vector3.ZERO
@export var glasses_scale := Vector3.ONE

@export_group("Depth & curve")
## Per-element depth offset from the head's face_z (metres; + = toward the viewer),
## to seat each part on a rounded head.
@export var eye_z := 0.0
@export var brow_z := 0.0
@export var nose_z := 0.0
@export var mouth_z := 0.0
@export var glasses_z := 0.03
## Convex wrap: the face bends around the head's horizontal round. Each element is set
## on a cylinder about the head's vertical axis, so it curves back AND tilts to face
## outward (not perpendicular-flat). face_curve is the curvature 1/radius: 0 = flat,
## higher = rounder (e.g. ~5 ≈ a 0.2 m-radius head).
@export var face_curve := 0.0


## Skeleton-space transform for an element at arc coords (x horizontal, y_off vertical) on
## the head. The face wraps on a SPHERE of radius 1/curve about the head centre, so the
## element bends back and tilts outward BOTH horizontally (from x) and vertically (from
## y_off) — that's why a centred nose/mouth still responds to curve. `rot` is euler degrees
## layered on the outward-facing orientation; `scl` scales the sprite (x width, y height).
func element_transform(
	head_index: int,
	x: float,
	y_off: float,
	z_off: float,
	curve := 0.0,
	rot := Vector3.ZERO,
	scl := Vector3.ONE
) -> Transform3D:
	var fz := face_z_for(head_index)
	var wx := x
	var wy := y_off
	var wz := fz + z_off
	var wrap := Basis.IDENTITY
	if absf(curve) > 0.0001:
		var r := 1.0 / curve
		var th := x * curve  # horizontal arc angle
		var tv := y_off * curve  # vertical arc angle
		wx = sin(th) * r
		wy = sin(tv) * r
		wz = fz + z_off - r * (1.0 - cos(th) * cos(tv))
		# Face outward along the sphere normal: yaw by th, pitch by -tv.
		wrap = Basis(Vector3.UP, th) * Basis(Vector3.RIGHT, -tv)
	var user := Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z)))
	var basis := wrap * user * Basis.from_scale(scl)
	return Transform3D(basis, Vector3(wx, head_y + wy, wz))


## The face depth for a given head index (its override, else the shared face_z).
func face_z_for(head_index: int) -> float:
	return float(head_face_z.get(head_index, face_z))


## Set the per-head face depth for a head index (used by the char preview's editor).
func set_face_z_for(head_index: int, value: float) -> void:
	head_face_z[head_index] = value


## The saved layout, or a fresh one with the defaults above if none exists yet.
static func load_or_default() -> FaceLayout:
	if ResourceLoader.exists(PATH):
		var r := load(PATH) as FaceLayout
		if r != null:
			return r
	return FaceLayout.new()
