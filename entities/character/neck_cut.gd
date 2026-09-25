class_name NeckCut
extends RefCounted

## Keeps the head's neck stub inside the worn top's collar. The tripo heads end in a neck
## stub that is wider than the shirt collars and reaches below them, so without a cut the
## skin shows over the collar band and the top of the tie knot. skin_face.gdshader cuts the
## head's skin away below a head-bone height (the head mesh carries its rest positions,
## FaceUvBaker) and shows the inside of the neck, shaded, where the cut opens; each top says
## where its collar sits (WardrobePart.neck_cut).

const OFF := -1.0


## Push the cut for `part` into the head's skin material; a null `part` is the rig's baked
## top (the single-breasted suit), and `worn` false (no top on) leaves the neck whole.
static func apply(mat: ShaderMaterial, part: WardrobePart, worn := true) -> void:
	if mat == null:
		return
	if part == null:
		part = Wardrobe.top(0)
	var on := worn and part != null
	mat.set_shader_parameter("neck_cut", part.neck_cut if on else OFF)
