class_name FaceStyle
extends Resource

## The look of a procedural face (assets/shaders/face_sdf.gdshaderinc): every eye, brow,
## nose and mouth parameter as data. Presets live in data/face_styles/. The rig (with
## CharacterRig.procedural_faces on) and the review sheets (tools/shot_faces.gd) push a
## style into a face element with apply(); expressions and blinks are the same fields
## overridden through a `dials` Dictionary (field name -> value), see expression().
##
## Units: each element is drawn on a square quad whose half-width is 1 ("q units", y up).
## QUAD_PX is that quad's size in the old sprite's texture pixels (pixel_size comes from the
## FaceLayout the painted sprites use). Every quad is larger than its old sprite so a style
## can move and size its element inside it: wide-set eyes, brows low over the eyes, a large
## nose, a mouth tucked up under the nose.
##
## Drawing language (every preset follows it): thin even strokes with round ends, no outline
## ring and no highlight in the eyes, a flat rose (or brown) nose dot, matte flat colour.

enum Element { EYE, BROW, NOSE, MOUTH }

## Large enough for low-set eyes with a cheek blush, low brows, a moustache and a wide grin.
const QUAD_PX := {Element.EYE: 720, Element.BROW: 1000, Element.NOSE: 260, Element.MOUTH: 240}
## Named iris colours, so CharacterRig.set_face_look("green", ...) still works.
const IRIS_COLORS := {
	"brown": Color("6b3a22"),
	"green": Color("4f6b3a"),
	"blue": Color("3f5f8f"),
	"amber": Color("a8662a"),
	"olive": Color("6b6a34"),
	"steel": Color("56687a"),
	"grey": Color("6f7478"),
	"hazel": Color("7a5a30"),
}
const NOSE_KINDS := 5  # dot, hook, arc, triangle, nostrils
const MOUTH_KINDS := 4  # stroke, cat "w", small "o", wide smile with ticks

static var _blank := {}

@export_group("Eye")
@export var eye_center := Vector2(-0.12, 0.0)
@export var eye_radii := Vector2(0.4, 0.46)
## Radians; > 0 lifts the outer corner.
@export var eye_tilt := 0.0
## Darker band under the upper lid, 0..1.
@export var top_shade := 0.0
@export var iris_radius := 0.25
## Iris offset from the eye centre, in screen directions (both eyes look the same way).
@export var gaze := Vector2(0.0, -0.08)
## Iris offset toward the nose on both eyes (a sliver of sclera shows on the outer side).
@export var iris_inset := 0.0
@export var pupil_radius := 0.25
@export_range(0.0, 1.0) var openness := 1.0
## Closes the right eye only (on screen; the mirrored sprite), 0..1.
@export_range(0.0, 1.0) var wink := 0.0
@export_range(0.0, 1.0) var squint := 0.0
## > 0 angry (inner corner of the lid down), < 0 sad (outer corner down).
@export_range(-1.0, 1.0) var lid_angle := 0.0
## Where the open upper lid rests, as a fraction of the eye's y radius above its centre:
## 1.06 clears the top (with lid_arch 0.5), 0 cuts the eye in half (a heavy lid).
@export var lid_height := 0.8
## How much the lid curves down at the corners, as a fraction of the y radius (0 = flat).
@export var lid_arch := 0.45
## Thickness of a dark band along the lid edge (0 = none). It stays on as the closed line.
@export var lid_band := 0.06
## Short wrinkle strokes fanned under the outer corner (0..3) and their length.
@export_range(0, 3) var corner_marks := 0
@export var corner_mark_len := 0.3
## A flat blush disc on each cheek: radius (0 = none) and offset from the eye centre (x < 0
## is outward, y < 0 down).
@export var blush_radius := 0.0
@export var blush_offset := Vector2(-0.2, -0.6)
## The lid line, lid band, closed eye and happy crescent.
@export var outline_color := Color("3a2418")
@export var sclera_color := Color("fff4e2")
@export var iris_color := Color("3a2418")
@export var pupil_color := Color("3a2418")
@export var corner_mark_color := Color("b07a52")
@export var blush_color := Color("e8a08a")

@export_group("Brow")
@export var brow_center := Vector2(-0.35, -0.15)
@export var brow_length := 0.9
@export var brow_thickness := 0.14
## Sag as a fraction of the length (> 0 arches up).
@export var brow_arch := 0.2
## Radians; > 0 lifts the inner end.
@export var brow_angle := 0.2
## Kept for old saves and presets; the shader caps it so the ends stay round (0 = even width).
@export_range(0.0, 1.0) var brow_taper := 0.0
@export var brow_raise := 0.0
@export var brow_angle_offset := 0.0
@export var brow_color := Color("3a2418")

@export_group("Nose")
## 0 dot, 1 hook, 2 arc, 3 triangle, 4 two nostril dots.
@export_range(0, 4) var nose_kind := 0
@export var nose_center := Vector2(0.0, 0.1)
@export var nose_size := 0.5
@export var nose_thickness := 0.08
@export var nose_color := Color("d98c7e")
## A moustache under the nose: full width (0 = none), stroke thickness, how far the tips
## turn up, and the gap below the nose dot.
@export var moustache_width := 0.0
@export var moustache_thickness := 0.11
@export var moustache_curl := 0.4
@export var moustache_gap := 0.07
@export var moustache_color := Color("5a3220")

@export_group("Mouth")
## 0 stroke, 1 cat "w", 2 small "o", 3 wide smile with corner ticks.
@export_range(0, 3) var mouth_kind := 0
@export var mouth_center := Vector2(0.0, 0.3)
@export var mouth_width := 0.5
@export var mouth_thickness := 0.075
## -1 frown .. 1 smile.
@export_range(-1.0, 1.0) var mouth_curve := 0.35
## > 0 lifts the right corner (on screen), < 0 the left.
@export_range(-1.0, 1.0) var mouth_skew := 0.0
@export_range(0.0, 1.0) var mouth_open := 0.0
## How deep a fully open mouth goes, relative to its half-width.
@export var mouth_depth := 0.9
## A white band of teeth under the top edge of the open mouth (the grin), 0..1.
@export_range(0.0, 1.0) var mouth_teeth := 0.0
## How much of the open mouth's depth the tongue fills from the bottom, 0..1.
@export_range(0.0, 1.0) var mouth_tongue := 0.0
@export var mouth_line_color := Color("3a2418")
@export var mouth_inner_color := Color("5a2a1c")
@export var mouth_tongue_color := Color("d0786a")
@export var mouth_teeth_color := Color("fff6ea")

@export_group("Expressions")
## Per-preset dials merged over expression()'s shared table: state name -> {field: value}.
@export var expression_overrides := {}


## The shader parameters for one element: {"element", "fp0".."fp5", "fc0".."fc5"} (13 of the
## 16 instance uniforms Godot allows per shader).
## `dials` overrides any field by name (an expression, a blink); `mirror` marks the flipped
## eye (its gaze is flipped back so both eyes agree on screen; it is the one that winks).
##   eye:   fp0 centre.xy radii.xy | fp1 tilt top_shade wink mirror
##          fp2 iris_r gaze.xy pupil_r | fp3 openness squint lid_angle corner_marks
##          fp4 lid_band lid_arch lid_height corner_mark_len
##          fp5 blush_offset.xy blush_radius iris_inset
##          fc0 outline (lid line, band, crescent), fc1 sclera, fc2 iris, fc3 pupil,
##          fc4 corner marks, fc5 blush
##   brow:  fp0 centre.xy length thickness | fp1 arch angle taper raise
##          fp2 angle_offset | fc0 colour
##   nose:  fp0 centre.xy size thickness | fp1 kind moustache_width moustache_thickness
##          moustache_curl | fp2 moustache_gap | fc0 nose, fc1 moustache
##   mouth: fp0 centre.xy width thickness | fp1 kind curve open depth | fp2 teeth tongue skew
##          fc0 line, fc1 inside, fc2 tongue, fc3 teeth
func pack(element: int, dials := {}, mirror := false) -> Dictionary:
	var v := func(key: String) -> Variant: return dials.get(key, get(key))
	var zero := Vector4.ZERO
	var out := {"element": element, "fp2": zero, "fp3": zero, "fp4": zero, "fp5": zero}
	match element:
		Element.EYE:
			var c: Vector2 = v.call("eye_center")
			var r: Vector2 = v.call("eye_radii")
			var g: Vector2 = v.call("gaze")
			var bo: Vector2 = v.call("blush_offset")
			out.fp0 = Vector4(c.x, c.y, r.x, r.y)
			out.fp1 = Vector4(
				v.call("eye_tilt"), v.call("top_shade"), v.call("wink"), 1.0 if mirror else 0.0
			)
			out.fp2 = Vector4(v.call("iris_radius"), g.x, g.y, v.call("pupil_radius"))
			out.fp3 = Vector4(
				v.call("openness"),
				v.call("squint"),
				v.call("lid_angle"),
				float(v.call("corner_marks")),
			)
			out.fp4 = Vector4(
				v.call("lid_band"),
				v.call("lid_arch"),
				v.call("lid_height"),
				v.call("corner_mark_len"),
			)
			out.fp5 = Vector4(bo.x, bo.y, v.call("blush_radius"), v.call("iris_inset"))
			out.fc0 = v.call("outline_color")
			out.fc1 = v.call("sclera_color")
			out.fc2 = v.call("iris_color")
			out.fc3 = v.call("pupil_color")
			out.fc4 = v.call("corner_mark_color")
			out.fc5 = v.call("blush_color")
		Element.BROW:
			var c: Vector2 = v.call("brow_center")
			out.fp0 = Vector4(c.x, c.y, v.call("brow_length"), v.call("brow_thickness"))
			out.fp1 = Vector4(
				v.call("brow_arch"),
				v.call("brow_angle"),
				v.call("brow_taper"),
				v.call("brow_raise")
			)
			out.fp2 = Vector4(v.call("brow_angle_offset"), 0.0, 0.0, 0.0)
			out.fc0 = v.call("brow_color")
		Element.NOSE:
			var c: Vector2 = v.call("nose_center")
			out.fp0 = Vector4(c.x, c.y, v.call("nose_size"), v.call("nose_thickness"))
			out.fp1 = Vector4(
				float(v.call("nose_kind")),
				v.call("moustache_width"),
				v.call("moustache_thickness"),
				v.call("moustache_curl"),
			)
			out.fp2 = Vector4(v.call("moustache_gap"), 0.0, 0.0, 0.0)
			out.fc0 = v.call("nose_color")
			out.fc1 = v.call("moustache_color")
		_:
			var c: Vector2 = v.call("mouth_center")
			out.fp0 = Vector4(c.x, c.y, v.call("mouth_width"), v.call("mouth_thickness"))
			out.fp1 = Vector4(
				float(v.call("mouth_kind")),
				v.call("mouth_curve"),
				v.call("mouth_open"),
				v.call("mouth_depth")
			)
			out.fp2 = Vector4(
				v.call("mouth_teeth"), v.call("mouth_tongue"), v.call("mouth_skew"), 0.0
			)
			out.fc0 = v.call("mouth_line_color")
			out.fc1 = v.call("mouth_inner_color")
			out.fc2 = v.call("mouth_tongue_color")
			out.fc3 = v.call("mouth_teeth_color")
	for k in ["fc1", "fc2", "fc3", "fc4", "fc5"]:
		if not out.has(k):
			out[k] = Color.WHITE
	return out


## Push this style into a face element: instance shader parameters on a 3D node (the rig's
## face Sprite3D with face_element.gdshader as material_override), or the ShaderMaterial
## of a CanvasItem (face_element_canvas.gdshader).
func apply(node: Node, element: int, dials := {}, mirror := false) -> void:
	var params := pack(element, dials, mirror)
	if node is GeometryInstance3D:
		for k: String in params:
			(node as GeometryInstance3D).set_instance_shader_parameter(k, params[k])
	elif node is CanvasItem and (node as CanvasItem).material is ShaderMaterial:
		var mat := (node as CanvasItem).material as ShaderMaterial
		for k: String in params:
			mat.set_shader_parameter(k, params[k])


## Dials for a named state, as absolute field values built from this style's rest look:
## neutral, blink_half, closed, happy, sad, angry, displeased, surprised, talking. A preset's
## expression_overrides for the state are merged over the shared table.
func expression(state: String) -> Dictionary:
	var states := {
		"blink_half": {"openness": 0.4},
		"closed": {"openness": 0.0},
		"happy":
		{
			"openness": 1.0,
			"squint": 1.0,
			"lid_height": maxf(lid_height, 1.0),
			"lid_arch": maxf(lid_arch, 0.45),
			"mouth_curve": 1.0,
			"brow_raise": brow_raise + 0.1,
		},
		"sad":
		{
			"lid_angle": -0.6,
			"brow_raise": brow_raise + 0.12,
			"brow_angle_offset": 0.35,
			"mouth_curve": -0.7,
		},
		"angry":
		{
			"lid_angle": 0.7,
			"brow_raise": brow_raise - 0.12,
			"brow_angle_offset": -0.4,
			"mouth_curve": minf(mouth_curve, 0.0) * 0.3,
		},
		"displeased":
		{
			"lid_angle": 0.3,
			"brow_raise": brow_raise - 0.08,
			"brow_angle_offset": -0.2,
			"mouth_curve": -0.6,
		},
		"surprised":
		{
			"iris_radius": iris_radius * 0.75,
			"pupil_radius": pupil_radius * 0.75,
			"brow_raise": brow_raise + 0.25,
			"mouth_kind": 2,
			"mouth_open": 1.0,
		},
		"talking": {"mouth_open": maxf(0.7, mouth_open)},
	}
	var out: Dictionary = states.get(state, {}).duplicate()
	out.merge(expression_overrides.get(state, {}), true)
	return out


## A plain white square texture sized so a Sprite3D shows `element`'s quad at the old
## sprite's world size (the shader draws everything; the texture only sets the size).
static func blank_texture(element: int) -> Texture2D:
	if not _blank.has(element):
		var side: int = QUAD_PX[element]
		var img := Image.create(side, side, false, Image.FORMAT_L8)
		img.fill(Color.WHITE)
		_blank[element] = ImageTexture.create_from_image(img)
	return _blank[element]
