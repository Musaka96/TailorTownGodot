class_name CharacterRig
extends Node3D

## Runtime controller for the shared character (built by tools/build_character.gd
## from CHARTGEN2 + KayKit Rig_Medium animations). Drives the AnimationPlayer
## (idle/walk/wave/accept) and manages a modular wardrobe: the head, HAIR, the TOP
## (jacket, shirt, buttons, pocket square, tie, and its own arms if it has any) and
## BOTTOM (trousers) are swappable slots. Each slot's mesh is
## pulled from a Wardrobe entry's .glb and reparented onto the shared skeleton —
## because every option is skinned to the same Rig_Medium, the animations drive it
## with no retargeting. Changing a suit style therefore changes the actual model,
## not just the colour.

# The base model's arms (hands, in skin): worn unless the top brings its own (a street
# outfit's hands sit in its own cuffs), in which case the base pair is set aside.
const SYLLABLE_TIME := 0.09  # how long syllable() holds the mouth open
const SKIN_ARMS := "arms"
# The base model's default meshes per slot (adopted on _ready as style/index 0).
const BAKED_HEAD := {"head": "head"}
# The top owns every piece cut to fit its jacket: each jacket model ships its own
# buttons, pocket square and tie (a double-breasted front sits the tie differently).
const BAKED_TOP := {
	"jacket": "jacket",
	"shirt": "shirt",
	"buttons": "buttons",
	"square": "square",
	"tie": "tie",
}
const BAKED_BOTTOM := {"pants": "legs"}
const BAKED_HAIR := {"hair": "Hair"}
# The top's pieces a street outfit leaves off (and a suit puts back on).
const SUIT_EXTRAS := ["buttons", "square", "tie"]
# The base model's own pair: worn with every suit. Street outfits swap in theirs.
const BAKED_SHOES := {"shoes": "shoes"}
# _top_style / _bottom_style while a street outfit's model is worn (no suit style), so
# the next set_outfit always swaps the suit back in.
const STREET_STYLE := -1
# Leather grain density on the shoe UVs. The shoe islands cover ~0.59 UV units per
# metre, so 8.3 keeps the grain the size it was on CHARTGEN1 (18 at ~0.27 per metre).
const SHOE_UV_SCALE := 8.3

# Two-layer hair: a flat base-colour mesh with a transparent strand-detail copy laid
# just over it (grown slightly so it never z-fights). Swap the PNG for real hair art.
const HAIR_STRANDS := "res://assets/textures/hair/strands.png"
const HAIR_OVERLAY_UV := 5.0
const HAIR_OVERLAY_GROW := 0.004

const DEFAULT_SKIN := Color(0.86, 0.72, 0.60)
const DEFAULT_SHIRT := Color(0.90, 0.90, 0.87)
const DEFAULT_HAIR := Color(0.14, 0.11, 0.09)
const DEFAULT_TIE := Color(0.55, 0.12, 0.14)  # dark red
const BUTTON_COLOR := Color(0.75, 0.62, 0.35)
const SQUARE_COLOR := Color(0.92, 0.92, 0.90)

# Casual colours for the placeholder street outfit (until street models exist).
const CASUAL_TOPS := [Color("6d7f9c"), Color("8a6d5b"), Color("5f7d5f"), Color("9c6d78")]
const CASUAL_BOTTOMS := [Color("39414f"), Color("5b4a3a"), Color("4a4a4a")]
## Muted knit ties for street clothes (see wear_street).
const STREET_TIES := [Color("3f4a5c"), Color("5c4a3f"), Color("4a5c4f"), Color("6b5a4a")]

# Fabric tiling across the mesh UVs (UV-mapped so the weave locks to the surface). Worn
# suits get a dark inverted-hull outline (next_pass) that reads each garment part apart.
# Fabric tiles per METRE of cloth: the garment UVs are laid out in metres by
# tools/blender/fix_garment_uvs.py, so this is a physical size, and the jacket,
# shirt and trousers all show the same fabric at the same scale.
const CLOTH_UV_SCALE := 6.0

# --- Locomotion / carry blending (AnimationTree) ---------------------------
# The rig blends on an AnimationTree: idle<->walk by speed, with the holding pose
# layered over ONLY the arm bones while carrying (so the legs keep striding and the
# torso keeps swaying). wave/accept fire as full-body one-shots over the blend.
const ARM_BONES := [
	"upperarm.l",
	"lowerarm.l",
	"wrist.l",
	"hand.l",
	"upperarm.r",
	"lowerarm.r",
	"wrist.r",
	"hand.r",
]
# How fast the blend params ease toward their targets (per second).
const LOCO_BLEND_SPEED := 6.0
const CARRY_BLEND_SPEED := 8.0
# How fast the walk-cycle playback speed eases toward its target (per second).
const LOCO_SPEED_BLEND := 8.0

# --- Carrying --------------------------------------------------------------
# A carried item hangs off a point parented to the right-hand bone, so it moves
# with the hand through the holding animation and turns with the character. The
# offset seats the item into the hands (tuned against the Holding_B pose).
const CARRY_BONE := "hand.r"
## Seat the item across the front (rotated flat like a carried bolt), tuned against
## the Holding_B two-handed pose.
const CARRY_POS := Vector3(0.02, 0.03, 0.16)
const CARRY_EULER := Vector3(0.0, PI * 0.5, 0.0)

# --- 2D face (cute animated eyes + mouth on the head) ----------------------
# Head bone the face rides on (KayKit Rig_Medium). Element positions, spacing and
# scale come from a FaceLayout resource (data/face_layout.tres) tuned in the Face
# Editor dock; a single eye/brow sprite is mirrored for the other side.
const FACE_BONE := "head_2"
const FACE_DIR := "res://assets/textures/faces/"
## Eye colours the art ships with; a customer is given one at random on spawn.
const EYE_COLORS := ["brown", "green", "blue", "amber", "olive", "steel"]
## Glasses are 3D parts (Wardrobe glasses, keyed by style); their frames come in these.
const GLASSES_COLORS := {
	"black": Color("1f1d21"),
	"tortoise": Color("5b3a22"),
	"gold": Color("c7a04c"),
	"silver": Color("b4b8bf"),
}
## The face depth the glasses parts are modelled for (the shaved base skull at eye
## height); each head moves them forward by its own face depth minus this.
const GLASSES_FACE_Z := 0.421
## The eye spacing the glasses are fitted to (paper_j1's); other faces scale them across.
const GLASSES_EYE_SPACING := 0.226
const LENS_TINT := Color(0.62, 0.72, 0.78, 0.25)
const BLINK_MIN := 2.4
const BLINK_MAX := 6.0
const BLINK_TIME := 0.11
# --- Expression + head gestures --------------------------------------------
# The face reacts while a suit is being fitted: brows rise and the mouth curls up
# when pleased, brows drop and the mouth turns down when not. A yes-nod / no-shake
# swings the whole face on a pivot under the head-bone attachment (the AnimationTree
# owns the skeleton, so we can't pose the head bone; swinging the face reads the
# same on the cute 2D face and never fights the animation).
const EXPR_BROW_LIFT := 0.022  # metres brows rise (pleased) / drop (displeased)
const EXPR_HAPPY_MOUTH := 1.2  # mouth grows into a grin when pleased
const NOD_ANGLE := 0.30
const SHAKE_ANGLE := 0.34
const GESTURE_STEP := 0.13
# --- Procedural faces (the game's faces; the sprites return if procedural_faces is off) ---
# The face is drawn IN THE HEAD'S SKIN MATERIAL (skin_face.gdshader) at a baked face UV
# (FaceUvBaker: UV2 = the head's flat front mapped to 0..1), from a FaceStyle
# (data/face_styles/, cut-paper pieces: docs/FACE_STYLE_GUIDE.md) laid out in face units, so
# one preset lands on every head. The glasses are 3D parts. Blinks, talking and
# expressions tween the style's dials (lid, mouth_open, mouth_curve, brow_height ...)
# instead of swapping art.
const SKIN_FACE_SHADER := "res://assets/shaders/skin_face.gdshader"
const DEFAULT_FACE_STYLE := "res://data/face_styles/paper_j1.tres"
const PROC_BLINK_CLOSE := 0.05
const PROC_BLINK_HOLD := 0.05
const PROC_BLINK_OPEN := 0.07
const PROC_EXPR_TIME := 0.18
const PROC_TALK_SPEED := 14.0  # mouth_open units per second while flapping
# With a procedural face the rest of the character is paper too (FACE_STYLE_GUIDE, "Paper
# skin and hair"): hands/arms and hair get paper_skin.gdshader, the face's grain at the
# mesh's UV1. Face units per UV unit, measured per mesh family so the fibres match the face
# (head UV1 ~0.47 per mesh unit, the face rect 1.68 face units wide): heads 4.0 (set in
# skin_face.gdshader), hair ~0.42 per unit, the base arms 1.39.
const PAPER_SKIN_SHADER := "res://assets/shaders/paper_skin.gdshader"
const PAPER_TILE_ARMS := 1.35
const PAPER_TILE_HAIR := 3.6
# Over the grain, the papier-mache surface (scan + torn strips, FACE_STYLE_GUIDE
# "Papier-mache surface"): a PaperSurface preset, the same on the head, arms and hair.
const DEFAULT_PAPER_SURFACE := "res://data/paper_surfaces/paper_mache.tres"

## Read once when a rig builds its face: true (live since 2026-09-27) = FaceStyle faces,
## false = the painted sprites (the fallback). Flip it before the rig enters the tree.
static var procedural_faces := true
## Procedural faces only: keep the strand overlay over the paper hair (false = the hair is
## pure flat paper). Read whenever the hair colour is applied.
static var paper_hair_strands := true
## Procedural faces only: the papier-mache surface of the skin and hair (null =
## DEFAULT_PAPER_SURFACE). Read whenever the skin or hair material is applied.
static var paper_surface: PaperSurface
static var _skin_face_shader: Shader
static var _paper_shader: Shader

## Procedural faces only: the FaceStyle the face draws (null until set = paper_j1.tres).
## Setting it clears any expression. A
## property rather than set_face_style(): this class is at gdlint's public-method limit.
var face_style: FaceStyle:
	get:
		return _face_style
	set(style):
		_set_face_style(style)
## The wearer's own leather: {"color", "finish"} (ShoeMaterial; missing or unknown
## values mean black calf), worn on the base pair with every suit. A street outfit
## with its own shoe leather shows that instead until the next set_outfit. Also a
## property for the public-method limit.
var shoes: Dictionary:
	get:
		return _shoes
	set(value):
		_set_shoes(value)
## The tie's colour (a flat, matte cloth). Kept across jacket swaps, since each jacket
## model brings its own tie. A property for the public-method limit, like `shoes`.
var tie_color: Color:
	get:
		return _tie_color
	set(value):
		_tie_color = value
		_dress_extras()
## The glasses frames' colour: a GLASSES_COLORS key (unknown = black). A property for
## the public-method limit; set it before or after set_face_look().
var glasses_color: String:
	get:
		return _glasses_color
	set(value):
		_glasses_color = value if GLASSES_COLORS.has(value) else "black"
		_paint_glasses()

var _tree: AnimationTree
var _loco := 0.0  # current idle(0)->walk(1) blend
var _loco_target := 0.0
var _carry_amt := 0.0  # current carry-overlay blend
var _carry_target := 0.0
var _loco_speed := 1.0  # current walk-cycle playback speed (1 = normal, >1 = sprint)
var _loco_speed_target := 1.0
var _carry_hold: Node3D

var _skel: Skeleton3D
var _layout: FaceLayout
var _head_inv := Transform3D.IDENTITY
var _wobble: HeadWobble  # rotates the head bone for nod/shake (face follows it)
var _expr := 0  # -1 displeased, 0 neutral, 1 pleased
var _gesture: Tween
var _eye_l: Sprite3D
var _eye_r: Sprite3D
var _brow_l: Sprite3D
var _brow_r: Sprite3D
var _nose: Sprite3D
var _mouth: Sprite3D
var _eye_color := "brown"
var _glasses_kind := ""  # "" or a Wardrobe glasses style; applied once the rig is ready
var _glasses_color := "black"
var _glasses_shown := ""  # the style whose meshes are attached now
var _glasses_attach: BoneAttachment3D  # on the head bone; the glasses meshes ride it
var _glasses_meshes: Array[MeshInstance3D] = []
var _nose_index := 0  # which nose_N sprite (see assets/textures/faces/)
var _mouth_index := 0  # which mouth_N sprite
var _talking := false  # auto-flap between closed/open mouth shapes (set_talking)
var _talk_timer := 0.0
var _talk_open := false
var _syllable_left := 0.0  # > 0 while a syllable() holds the mouth open
var _blink: Timer
var _proc := false  # this rig's face is procedural (procedural_faces when it was built)
var _skin_face: ShaderMaterial  # the head's skin + face material (procedural faces)
var _face_frame: FaceFrame  # the current head's face rect (null = no face UV, no face)
var _face_style: FaceStyle
var _look_set := false  # set_face_look() was called
var _dials := {}  # current values of the animated FaceStyle fields
var _expr_target := {}  # the expression's dials the face is heading to / holding
var _blink_tween: Tween
var _expr_tween: Tween
var _mouth_open_target := 0.0
# Each slot maps role -> MeshInstance3D currently filling it.
var _head: Dictionary = {}
var _top: Dictionary = {}
var _bottom: Dictionary = {}
var _hair: Dictionary = {}
# Currently-shown style/index, so we only re-instance a model when it changes.
var _head_index := 0
var _top_style := 0
var _bottom_style := 0
var _hair_index := 0
# Skin tint (kept so it re-applies whenever the head mesh is swapped).
var _skin_color := DEFAULT_SKIN
# Tint applied to the hair mesh (kept so it survives a hairstyle swap).
var _hair_color := DEFAULT_HAIR
var _shoes: Dictionary = {}
var _shoe_slot: Dictionary = {}  # role "shoes" -> the MeshInstance3D worn
var _shoe_part: WardrobePart  # the swapped-in shoe model; null = the base pair
var _street_shoes := false  # the shoes show a street outfit's leather, not _shoes
var _tie_color := DEFAULT_TIE
var _base_arms: MeshInstance3D  # the base model's arms, kept while a top wears its own

@onready var _anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_skel = find_child("Skeleton3D", true, false) as Skeleton3D
	_head = _adopt(BAKED_HEAD)
	_top = _adopt(BAKED_TOP)
	_bottom = _adopt(BAKED_BOTTOM)
	_hair = _adopt(BAKED_HAIR)
	_shoe_slot = _adopt(BAKED_SHOES)
	_base_arms = find_child(SKIN_ARMS, true, false) as MeshInstance3D
	_set_shoes({})  # black calf until someone says otherwise
	_dress_extras()
	if _anim != null:
		# Install the animation set from the editable asset (shared, cached), so
		# changing data/animations/default_animations.tres takes effect next run.
		if _anim.has_animation_library(""):
			_anim.remove_animation_library("")
		_anim.add_animation_library("", CharAnims.library())
		_build_tree()
	_build_face()
	_build_carry()
	_build_head_wobble()


func _process(delta: float) -> void:
	_update_mouth(delta)
	if _tree == null:
		return
	_loco = move_toward(_loco, _loco_target, LOCO_BLEND_SPEED * delta)
	_carry_amt = move_toward(_carry_amt, _carry_target, CARRY_BLEND_SPEED * delta)
	_loco_speed = move_toward(_loco_speed, _loco_speed_target, LOCO_SPEED_BLEND * delta)
	_tree.set("parameters/loco/blend_amount", _loco)
	_tree.set("parameters/carry/blend_amount", _carry_amt)
	_tree.set("parameters/loco_ts/scale", _loco_speed)


func _notification(what: int) -> void:
	# Base arms set aside are outside the tree, so the rig must free them itself.
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_base_arms):
		if _base_arms.get_parent() == null:
			_base_arms.free()


# --- 2D face ---------------------------------------------------------------


## Mount cute eyes + brows + nose + mouth on the head bone, laid out from a
## FaceLayout. Billboard is OFF (the camera is fixed and characters turn away, so the
## face must rotate with the head, not the camera); double-sided OFF means it simply
## vanishes when they face away. Eyes blink on their own timer; the mouth flaps while
## set_talking(true). A single eye/brow sprite is mirrored for the other side.
func _build_face() -> void:
	if _skel == null:
		return
	var idx := _skel.find_bone(FACE_BONE)
	if idx < 0:
		return
	_layout = FaceProfiles.load_or_default().layout_for(_head_index)
	_head_inv = _skel.get_bone_global_pose(idx).affine_inverse()
	var attach := BoneAttachment3D.new()
	attach.name = "FaceAttach"
	attach.bone_name = FACE_BONE
	_skel.add_child(attach)
	_proc = procedural_faces
	if not _proc:  # a procedural face lives in the head material (only glasses are sprites)
		_eye_l = _sprite(attach, _eye_tex(), false)
		_eye_r = _sprite(attach, _eye_tex(), true)
		_brow_l = _sprite(attach, _tex("brow"), false)
		_brow_r = _sprite(attach, _tex("brow"), true)
		_nose = _sprite(attach, _tex("nose_%d" % _nose_index), false)
		_mouth = _sprite(attach, _tex("mouth_%d" % _mouth_index), false)
		# Name them so tools (the char preview gizmo) can find the element to manipulate.
		_eye_l.name = "eye_l"
		_brow_l.name = "brow_l"
		_nose.name = "nose"
		_mouth.name = "mouth"
	if _proc:
		_make_procedural()
	apply_layout(_layout)
	_apply_glasses()  # honour any look set before the face was built
	_blink = Timer.new()
	_blink.one_shot = true
	add_child(_blink)
	_blink.timeout.connect(_do_blink)
	_schedule_blink()


## Reposition/scale every face element from a layout — live-editable by the Face
## Editor dock, and read once at spawn for normal play.
func apply_layout(layout: FaceLayout) -> void:
	if layout == null:
		return
	_layout = layout
	var base := layout.face_curve
	var ex := layout.eye_x
	_place_pair(
		_eye_l,
		_eye_r,
		-layout.eye_gap * 0.5 + ex,
		layout.eye_gap * 0.5 + ex,
		layout.eye_y,
		layout.eye_px,
		layout.eye_z,
		base + layout.eye_curve,
		layout.eye_rot,
		layout.eye_scale
	)
	var bx := layout.brow_x
	_place_pair(
		_brow_l,
		_brow_r,
		-layout.brow_gap * 0.5 + bx,
		layout.brow_gap * 0.5 + bx,
		layout.brow_y,
		layout.brow_px,
		layout.brow_z,
		base + layout.brow_curve,
		layout.brow_rot,
		layout.brow_scale
	)
	_place_one(_nose, layout, "nose", base)
	_place_one(_mouth, layout, "mouth", base)
	_place_glasses()


## Place a single (centred) element by name, reading its x/y/px/z/curve/rot/scale fields.
func _place_one(node: Node3D, layout: FaceLayout, key: String, base: float) -> void:
	_place(
		node,
		layout.get(key + "_x"),
		layout.get(key + "_y"),
		layout.get(key + "_px"),
		layout.get(key + "_z"),
		base + layout.get(key + "_curve"),
		layout.get(key + "_rot"),
		layout.get(key + "_scale")
	)


## Place a mirrored pair (eyes/brows). The right element mirrors yaw+roll so a tilt reads
## symmetrically; pitch and scale are shared.
func _place_pair(
	nl: Node3D,
	nr: Node3D,
	xl: float,
	xr: float,
	y: float,
	px: float,
	z: float,
	curve: float,
	rot: Vector3,
	scl: Vector3
) -> void:
	_place(nl, xl, y, px, z, curve, rot, scl)
	_place(nr, xr, y, px, z, curve, Vector3(rot.x, -rot.y, -rot.z), scl)


## The mouth flaps between a closed and an open shape while a line is being said
## (called by the dialogue UI). Which sprites count as closed/open is data:
## res://data/mouth_shapes.tres (MouthShapes).
func set_talking(on: bool) -> void:
	_talking = on
	_talk_timer = 0.0
	if _proc:
		if not on and _syllable_left <= 0.0:
			_mouth_open_target = 0.0
		return
	if not on and _syllable_left <= 0.0:
		_show_mouth(_mouth_index)


## Open the mouth for one syllable (lip-sync to a talk sound), then close it again.
func syllable() -> void:
	_syllable_left = SYLLABLE_TIME
	if _proc:
		_mouth_open_target = randf_range(0.45, 0.8)
		return
	_show_mouth(_open_frame())


func _update_mouth(delta: float) -> void:
	if _proc:
		_update_mouth_proc(delta)
		return
	if _mouth == null:
		return
	if _syllable_left > 0.0:
		_syllable_left -= delta
		if _syllable_left <= 0.0:
			_show_mouth(_closed_frame() if _talking else _mouth_index)
		return
	if not _talking:
		return
	_talk_timer -= delta
	if _talk_timer <= 0.0:
		_talk_open = not _talk_open
		_talk_timer = randf_range(0.07, 0.12)
		_show_mouth(_open_frame() if _talk_open else _closed_frame())


func _closed_frame() -> int:
	return MouthShapes.load_or_default().closed_for(_mouth_index)


## A random open shape — mostly wide, sometimes just parted — for a natural chatter.
func _open_frame() -> int:
	var shapes := MouthShapes.load_or_default()
	var wide := shapes.of_kind(MouthShapes.Kind.WIDE_OPEN)
	var small := shapes.of_kind(MouthShapes.Kind.SMALL_OPEN)
	var pool := small if (randf() < 0.35 and not small.is_empty()) or wide.is_empty() else wide
	return pool[randi() % pool.size()] if not pool.is_empty() else _mouth_index


func _show_mouth(index: int) -> void:
	if _mouth != null:
		_mouth.texture = _tex("mouth_%d" % index)


## React while being fitted: a lasting smile (liked) or frown (disliked). Brows and
## mouth shift and hold until reset; express_once() pairs it with a one-off gesture.
func set_expression(liked: bool) -> void:
	_apply_expression(1 if liked else -1)


## Return to the resting face (called when the fitting menu closes).
func reset_expression() -> void:
	_apply_expression(0)


## A momentary reaction to a suggestion: grin + nod (liked) or frown + "no-no" shake
## (disliked), which then eases back to the resting face on its own.
func express_once(liked: bool) -> void:
	_apply_expression(1 if liked else -1)
	if liked:
		_nod()
	else:
		_shake()
	if _gesture != null and _gesture.is_valid():
		_gesture.tween_interval(0.5)  # let the expression linger a beat past the swing
		_gesture.tween_callback(func() -> void: _apply_expression(0))


## A happy yes-nod (pitch) — a quick swing that settles back to centre.
func _nod() -> void:
	_swing("pitch", NOD_ANGLE, [1.0, -0.35, 0.5, 0.0])


## A no-no head shake (yaw) — used when the customer dislikes the design.
func _shake() -> void:
	_swing("yaw", SHAKE_ANGLE, [1.0, -1.0, 0.6, -0.35, 0.0])


func _apply_expression(mood: int) -> void:
	_expr = mood
	if _proc:
		_proc_expression("happy" if mood > 0 else ("displeased" if mood < 0 else ""))
		return
	if _layout == null:
		return
	var lift := EXPR_BROW_LIFT * mood
	var bc := _layout.face_curve + _layout.brow_curve
	var bx := _layout.brow_x
	var by := _layout.brow_y + lift
	var bz := _layout.brow_z
	var bpx := _layout.brow_px
	var br: Vector3 = _layout.brow_rot
	var bs: Vector3 = _layout.brow_scale
	var brm := Vector3(br.x, -br.y, -br.z)
	_place(_brow_l, -_layout.brow_gap * 0.5 + bx, by, bpx, bz, bc, br, bs)
	_place(_brow_r, _layout.brow_gap * 0.5 + bx, by, bpx, bz, bc, brm, bs)
	if _mouth != null:
		_mouth.flip_v = mood < 0  # the resting smile, flipped over into a frown
		_mouth.pixel_size = _layout.mouth_px * (EXPR_HAPPY_MOUTH if mood > 0 else 1.0)


## Swing the head bone through a sequence of angle multiples, back to rest. `prop` is
## the wobble axis to drive ("pitch" for a nod, "yaw" for a shake).
func _swing(prop: String, angle: float, steps: Array) -> void:
	if _wobble == null:
		return
	if _gesture != null and _gesture.is_valid():
		_gesture.kill()
	_wobble.set(prop, 0.0)
	_gesture = create_tween()
	for s: float in steps:
		_gesture.tween_property(_wobble, prop, angle * s, GESTURE_STEP)


## Attach the head-bone wobble modifier so nod/shake rotate the real head (the face,
## riding the same bone, follows). Runs after the AnimationTree poses the skeleton.
func _build_head_wobble() -> void:
	if _skel == null:
		return
	var idx := _skel.find_bone(FACE_BONE)
	if idx < 0:
		return
	_wobble = HeadWobble.new()
	_wobble.name = "HeadWobble"
	_wobble.bone = idx
	_skel.add_child(_wobble)


func _place(
	node: Node3D,
	x: float,
	y_off: float,
	px: float,
	z_off := 0.0,
	curve := 0.0,
	rot := Vector3.ZERO,
	scl := Vector3.ONE
) -> void:
	if node == null or _layout == null:
		return
	node.transform = (
		_head_inv * _layout.element_transform(_head_index, x, y_off, z_off, curve, rot, scl)
	)
	node.pixel_size = px


func _sprite(parent: Node, tex: Texture2D, mirror: bool) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.flip_h = mirror
	_face_flags(s)
	parent.add_child(s)
	return s


func _face_flags(s: SpriteBase3D) -> void:
	s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	s.shaded = false
	s.double_sided = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD


func _schedule_blink() -> void:
	if _blink != null:
		_blink.start(randf_range(BLINK_MIN, BLINK_MAX))


## Blink by swapping the eyes to the squashed "closed" frame for a moment.
func _do_blink() -> void:
	if _proc:
		_proc_blink()
		_schedule_blink()
		return
	_set_eye_tex(_tex("eye_closed"))
	get_tree().create_timer(BLINK_TIME).timeout.connect(_open_eyes)
	_schedule_blink()


func _open_eyes() -> void:
	_set_eye_tex(_eye_tex())


func _set_eye_tex(tex: Texture2D) -> void:
	if _eye_l != null:
		_eye_l.texture = tex
	if _eye_r != null:
		_eye_r.texture = tex


## Set eye colour (one of EYE_COLORS; unknown falls back to brown so blinks never
## break) and glasses (a Wardrobe glasses style, or "" for none; the old sprite keys
## "round" / "sun" still work) — the per-customer face look.
func set_face_look(eye_color: String, glasses: String, nose := -1, mouth := -1) -> void:
	_eye_color = eye_color if eye_color in EYE_COLORS else "brown"
	_glasses_kind = Wardrobe.glasses_style(glasses)
	_look_set = true
	if _proc:
		if nose >= 0:
			_nose_index = nose
		_proc_look()
		_apply_glasses()
		return
	if nose >= 0:
		_set_nose(nose)
	if mouth >= 0:
		_set_mouth(mouth)
	if not _is_blinking():
		_set_eye_tex(_eye_tex())
	_apply_glasses()


## Put on the stored glasses style (or take them off for ""). Safe before the rig is
## ready (the face builder calls it again), so spawn-time set_face_look() never misses.
func _apply_glasses() -> void:
	if _skel == null or _skel.find_bone(FACE_BONE) < 0:
		return
	if _glasses_kind != _glasses_shown:
		_clear_glasses()
		var part := Wardrobe.library().glasses_part(_glasses_kind)
		if part != null and part.model != null:
			_attach_glasses(part)
		_glasses_shown = _glasses_kind
	_place_glasses()
	_paint_glasses()


## The glasses meshes ride a head-bone attachment as plain (unskinned) meshes, so they
## can be moved onto each head's face plane; the part's skin bind for the head bone
## puts them where the skinned mesh would sit.
func _attach_glasses(part: WardrobePart) -> void:
	if _glasses_attach == null:
		_glasses_attach = BoneAttachment3D.new()
		_glasses_attach.name = "GlassesAttach"
		_glasses_attach.bone_name = FACE_BONE
		_skel.add_child(_glasses_attach)
	var inst := part.model.instantiate()
	for role in part.roles:
		var src := inst.find_child(part.roles[role], true, false) as MeshInstance3D
		if src == null or src.mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = role
		mi.mesh = src.mesh
		mi.set_meta("role", role)
		mi.set_meta("bind", _head_bind(src))
		_glasses_attach.add_child(mi)
		_glasses_meshes.append(mi)
	inst.free()


## Mesh space -> head-bone space for a part's mesh: its skin's bind pose for the head
## bone ("head" in the part's own rig, "head_2" once renamed), else the rest pose.
func _head_bind(src: MeshInstance3D) -> Transform3D:
	var skin := src.skin
	if skin != null:
		var src_skel := src.get_node_or_null(src.skeleton) as Skeleton3D
		for i in skin.get_bind_count():
			var bn := String(skin.get_bind_name(i))
			if bn == "" and src_skel != null and skin.get_bind_bone(i) >= 0:
				bn = src_skel.get_bone_name(skin.get_bind_bone(i))
			if bn in ["head", FACE_BONE] or skin.get_bind_count() == 1:
				return skin.get_bind_pose(i)
	var rest := _skel.get_bone_global_rest(_skel.find_bone(FACE_BONE))
	return rest.affine_inverse() * src.transform


## Move the glasses forward (skeleton +z) onto this head's face plane and, on a procedural
## face, scale them across (x) to its eye spacing so the lenses land on the eyes.
func _place_glasses() -> void:
	if _glasses_meshes.is_empty():
		return
	var layout := _layout if _layout != null else FaceProfiles.load_or_default().layout_for(0)
	var dz := layout.face_z_for(_head_index) - GLASSES_FACE_Z
	var across := 1.0
	if _proc:
		across = _face_style_or_default().eye_spacing / GLASSES_EYE_SPACING
	var shift := Transform3D(Basis.from_scale(Vector3(across, 1.0, 1.0)), Vector3(0.0, 0.0, dz))
	for mi in _glasses_meshes:
		mi.transform = (mi.get_meta("bind") as Transform3D) * shift


## Frames: a flat outlined colour from GLASSES_COLORS. Lenses: a light transparent tint.
func _paint_glasses() -> void:
	for mi in _glasses_meshes:
		if mi.get_meta("role") == "lenses":
			var lens := StandardMaterial3D.new()
			lens.albedo_color = LENS_TINT
			lens.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			lens.roughness = 0.2
			lens.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			mi.material_override = lens
		else:
			_apply_flat(mi, GLASSES_COLORS.get(_glasses_color, GLASSES_COLORS["black"]), 1.0)


func _clear_glasses() -> void:
	for mi in _glasses_meshes:
		if is_instance_valid(mi):
			mi.get_parent().remove_child(mi)
			mi.queue_free()
	_glasses_meshes.clear()


func _eye_tex() -> Texture2D:
	return _tex("eye_" + _eye_color)


func _is_blinking() -> bool:
	return _eye_l != null and _eye_l.texture == _tex("eye_closed")


static func _tex(sprite_name: String) -> Texture2D:
	return load(FACE_DIR + sprite_name + ".png") as Texture2D


# --- Nose / mouth selection ------------------------------------------------


## Number of nose_N / mouth_N variants sliced into assets/textures/faces/.
static func variant_count(prefix: String) -> int:
	var n := 0
	while ResourceLoader.exists("%s%s_%d.png" % [FACE_DIR, prefix, n]):
		n += 1
	return n


func _set_nose(index: int) -> void:
	_nose_index = posmod(index, maxi(1, variant_count("nose")))
	if _nose != null:
		_nose.texture = _tex("nose_%d" % _nose_index)


func _set_mouth(index: int) -> void:
	_mouth_index = posmod(index, maxi(1, variant_count("mouth")))
	if _mouth != null:
		_mouth.texture = _tex("mouth_%d" % _mouth_index)


# --- Procedural face (POC) -------------------------------------------------


func _set_face_style(style: FaceStyle) -> void:
	_face_style = style
	_dials.clear()
	_expr_target = {}
	if _look_set:
		_proc_look()
	if _proc:
		_push_face()
		_place_glasses()  # their width follows the face's eye spacing


## Put the face on the head: bake the current head's face UV, give it the face skin and
## push the style (set_head() does the same for every later head).
func _make_procedural() -> void:
	_face_style_or_default()
	if _look_set:
		_proc_look()
	_bake_face_head()
	_apply_skin()
	_apply_hair_color()


## Procedural faces: swap the head's mesh for a copy with the face UV (FaceUvBaker, cached
## per head model) and keep its face rect. No face bone or no front found = no face drawn.
func _bake_face_head() -> void:
	_face_frame = null
	var head_mi = _head.get("head")
	if not _proc or _skel == null or not (head_mi is MeshInstance3D):
		return
	var bone := _skel.find_bone(FACE_BONE)
	if bone < 0:
		return
	var baked := FaceUvBaker.bake(head_mi.mesh, _global_rest(_skel, bone).affine_inverse())
	if baked.is_empty():
		return
	head_mi.mesh = baked.mesh
	_face_frame = baked.frame


## The head's skin material with the face in it (one per rig): skin colour, face on/off,
## and the style pushed in.
func _face_skin() -> ShaderMaterial:
	if _skin_face == null:
		if _skin_face_shader == null:
			_skin_face_shader = load(SKIN_FACE_SHADER) as Shader
		_skin_face = ShaderMaterial.new()
		_skin_face.shader = _skin_face_shader
	_skin_face.set_shader_parameter("skin_color", _skin_color)
	_skin_face.set_shader_parameter("face_enabled", _face_frame != null)
	_paper_look().apply_to(_skin_face)
	_push_face()
	return _skin_face


## Push the style + current dials into the head's face material. `_element` is kept for
## the callers that only changed one element (the material takes every uniform anyway).
func _push_face(_element := -1) -> void:
	if not _proc or _face_style == null or _skin_face == null:
		return
	_face_style.apply_to_material(_skin_face, _dials, _face_frame)


## set_face_look() in procedural terms: nothing to change. Cut-paper eyes have no iris
## colour (the guide's closed palette), and the style owns the nose and the mouth, so
## their indices are ignored.
func _proc_look() -> void:
	_face_style_or_default()
	_push_face()


func _face_style_or_default() -> FaceStyle:
	if _face_style == null:
		_face_style = load(DEFAULT_FACE_STYLE) as FaceStyle
	return _face_style


## Resting value of a dial: the held expression's, else the style's own.
func _rest(key: String) -> Variant:
	return _expr_target.get(key, _face_style_or_default().get(key))


func _set_dial(value: Variant, key: String, element: int) -> void:
	_dials[key] = value
	_push_face(element)


func _proc_blink() -> void:
	if _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()
	var rest: float = _rest("lid")
	var set_lid := _set_dial.bind("lid", FaceStyle.Element.EYE)
	_blink_tween = create_tween()
	_blink_tween.tween_method(set_lid, rest, 1.0, PROC_BLINK_CLOSE)
	_blink_tween.tween_interval(PROC_BLINK_HOLD)
	_blink_tween.tween_method(set_lid, 1.0, rest, PROC_BLINK_OPEN)


## Tween the face to a named FaceStyle.expression() ("" = back to the resting style).
func _proc_expression(state: String) -> void:
	var style := _face_style_or_default()
	var target := style.expression(state) if state != "" else {}
	var from := {}
	var to := {}
	for k: String in _expr_target.keys() + target.keys():
		var goal: Variant = target.get(k, style.get(k))
		if goal is int:
			_dials[k] = goal  # kinds switch, they don't blend
			continue
		from[k] = _dials.get(k, style.get(k))
		to[k] = goal
	_expr_target = target
	if _expr_tween != null and _expr_tween.is_valid():
		_expr_tween.kill()
	_expr_tween = create_tween()
	_expr_tween.tween_method(_blend_dials.bind(from, to), 0.0, 1.0, PROC_EXPR_TIME)


func _blend_dials(t: float, from: Dictionary, to: Dictionary) -> void:
	for k: String in to:
		_dials[k] = lerp(from[k], to[k], t)
	_push_face()


## Talking on a procedural face: the mouth_open dial chases a flapping target.
func _update_mouth_proc(delta: float) -> void:
	if _syllable_left > 0.0:
		_syllable_left -= delta
		if _syllable_left <= 0.0:
			_mouth_open_target = 0.0
	elif _talking:
		_talk_timer -= delta
		if _talk_timer <= 0.0:
			_talk_open = not _talk_open
			_talk_timer = randf_range(0.07, 0.12)
			_mouth_open_target = randf_range(0.45, 0.8) if _talk_open else 0.05
	var rest: float = _rest("mouth_open")
	var goal := maxf(_mouth_open_target, rest)
	if rest > 0.01 and _mouth_open_target > 0.0:
		# a mouth held open (a happy face) pulses around its rest size while talking
		goal = clampf(rest + (_mouth_open_target - 0.45) * 0.8, 0.05, 0.8)
	var cur: float = _dials.get("mouth_open", rest)
	if not is_equal_approx(cur, goal):
		_dials["mouth_open"] = move_toward(cur, goal, PROC_TALK_SPEED * delta)
		_push_face(FaceStyle.Element.MOUTH)


# --- Carrying --------------------------------------------------------------


## The point a carried item attaches to — parented to the hand bone, so the item
## follows the hand and turns with the character. Null until the rig is ready.
func carry_point() -> Node3D:
	return _carry_hold


## Whether the character is holding something; eases the arm-only holding overlay
## in/out (see _process).
func set_carrying(on: bool) -> void:
	_carry_target = 1.0 if on else 0.0


## Build the hand-bone attachment the carried item rides on.
func _build_carry() -> void:
	if _skel == null or _skel.find_bone(CARRY_BONE) < 0:
		return
	var attach := BoneAttachment3D.new()
	attach.name = "CarryAttach"
	attach.bone_name = CARRY_BONE
	_skel.add_child(attach)
	_carry_hold = Node3D.new()
	_carry_hold.name = "CarryHold"
	_carry_hold.transform = Transform3D(Basis.from_euler(CARRY_EULER), CARRY_POS)
	attach.add_child(_carry_hold)


# --- Animation -------------------------------------------------------------


## Standing vs walking, as a boolean — eases the idle<->walk blend fully in/out.
## For a smoother, speed-proportional blend, call set_locomotion instead.
func set_moving(moving: bool) -> void:
	_loco_target = 1.0 if moving else 0.0


## Drive the idle<->walk blend directly from a 0..1 speed ratio (the player passes
## its horizontal speed / max speed), so setting off and stopping ease naturally.
func set_locomotion(speed_ratio: float) -> void:
	_loco_target = clampf(speed_ratio, 0.0, 1.0)


## Scale the walk-cycle playback speed (1 = normal, >1 = sprint), eased in _process
## so the legs visibly quicken when the player sprints.
func set_locomotion_speed(mult: float) -> void:
	_loco_speed_target = maxf(0.1, mult)


## A friendly wave — a full-body one-shot layered over the current blend.
func wave() -> void:
	if _tree != null:
		_tree.set("parameters/wave/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Play the accept/celebrate gesture; `done` fires when it finishes (customers use
## it to leave afterwards). A full-body one-shot over the blend.
func celebrate(done := Callable()) -> void:
	if _tree == null:
		if done.is_valid():
			done.call()
		return
	_tree.set("parameters/accept/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	if done.is_valid():
		var length := 0.6
		var clip := _anim.get_animation("accept") if _anim != null else null
		if clip != null:
			length = clip.length
		get_tree().create_timer(length).timeout.connect(done)


## Build the blend tree: idle<->walk by speed, the holding pose layered over only
## the arm bones while carrying, and wave/accept as full-body one-shots on top.
func _build_tree() -> void:
	var tree := AnimationNodeBlendTree.new()
	tree.add_node("idle", _anim_node("idle"))
	tree.add_node("walk", _anim_node("walk"))
	tree.add_node("carry_pose", _anim_node("carry"))
	tree.add_node("wave_pose", _anim_node("wave"))
	tree.add_node("accept_pose", _anim_node("accept"))

	var loco := AnimationNodeBlend2.new()
	tree.add_node("loco", loco)
	tree.connect_node("loco", 0, "idle")
	tree.connect_node("loco", 1, "walk")

	# Speed control on the locomotion (quickens the walk cycle when sprinting).
	var loco_ts := AnimationNodeTimeScale.new()
	tree.add_node("loco_ts", loco_ts)
	tree.connect_node("loco_ts", 0, "loco")

	# Arm-only holding overlay: filter the arm bone tracks so at amount 1 the arms
	# come from the holding pose while everything else stays with locomotion.
	var carry := AnimationNodeBlend2.new()
	carry.filter_enabled = true
	tree.add_node("carry", carry)
	tree.connect_node("carry", 0, "loco_ts")
	tree.connect_node("carry", 1, "carry_pose")

	var wave_os := AnimationNodeOneShot.new()
	wave_os.fadein_time = 0.15
	wave_os.fadeout_time = 0.25
	tree.add_node("wave", wave_os)
	tree.connect_node("wave", 0, "carry")
	tree.connect_node("wave", 1, "wave_pose")

	var accept_os := AnimationNodeOneShot.new()
	accept_os.fadein_time = 0.15
	accept_os.fadeout_time = 0.25
	tree.add_node("accept", accept_os)
	tree.connect_node("accept", 0, "wave")
	tree.connect_node("accept", 1, "accept_pose")
	tree.connect_node("output", 0, "accept")

	_apply_arm_filter(carry)

	_tree = AnimationTree.new()
	_tree.tree_root = tree
	add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_anim)
	_tree.active = true
	# Pose the rig right away: the game may pause before the first animation frame runs,
	# which would otherwise leave the character standing in its T-pose.
	_tree.advance(0.0)


func _anim_node(clip: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = clip
	return node


## Filter the carry blend to the arm bone tracks (matched against the real track
## paths of the carry clip, so the path format is always exact).
func _apply_arm_filter(blend: AnimationNodeBlend2) -> void:
	var clip := _anim.get_animation("carry") if _anim != null else null
	if clip == null:
		return
	for i in clip.get_track_count():
		var path := clip.track_get_path(i)
		if String(path).get_slice(":", 1) in ARM_BONES:
			blend.set_filter_path(path, true)


# --- Wardrobe --------------------------------------------------------------


## Colour the exposed skin (the current head mesh + arms). Kept so a head swap
## re-applies the same tone.
func set_palette(skin: Color) -> void:
	_skin_color = skin
	_apply_skin()


## Swap to head `index` from the Wardrobe (no-op if already shown). Index 0 is the base
## baked head, so the common case never re-instances a model. The face mesh is given a
## flat skin material, so the 2D animated eyes/brows/mouth read on top of it.
func set_head(index: int) -> void:
	if index == _head_index and not _head.is_empty():
		return
	_head = _clear(_head)
	var part := Wardrobe.head(index)
	if part != null and part.model != null:
		_head = _attach_from(part.model, part.roles)
	if _head.is_empty():
		_head = _adopt(BAKED_HEAD)  # fall back to the base head
	_head_index = index
	_bake_face_head()
	_apply_skin()
	# Load this head/combo's own face profile so each head carries its own tuning.
	_layout = FaceProfiles.load_or_default().layout_for(index)
	apply_layout(_layout)


func _apply_skin() -> void:
	var mat := _flat(_skin_color, 0.7)
	var head_mi = _head.get("head")
	if head_mi is MeshInstance3D:
		head_mi.material_override = _face_skin() if _proc else mat
	var arms = _top.get("arms", _base_arms)
	if arms is MeshInstance3D:
		arms.material_override = _paper(_skin_color, PAPER_TILE_ARMS, 0.0) if _proc else mat


## Swap to hairstyle `index` from the Wardrobe (no-op if already shown).
func set_hair(index: int) -> void:
	if index == _hair_index and not _hair.is_empty():
		return
	_hair = _clear(_hair)
	var part := Wardrobe.hair(index)
	if part != null and part.model != null:
		_hair = _attach_from(part.model, part.roles)
	_build_hair_overlay()
	_hair_index = index
	_apply_hair_color()


## Tint the hair (kept and re-applied whenever the hairstyle mesh is swapped).
func set_hair_color(color: Color) -> void:
	_hair_color = color
	_apply_hair_color()


## Lay a transparent strand-detail copy of the hair mesh just over the base mesh, so
## the flat base colour shows through the gaps and the texture reads as strands.
func _build_hair_overlay() -> void:
	var base = _hair.get("hair")
	if not (base is MeshInstance3D) or _skel == null:
		return
	var overlay := (base as MeshInstance3D).duplicate() as MeshInstance3D
	overlay.name = "hair_overlay"
	_skel.add_child(overlay)
	overlay.skeleton = NodePath("..")
	_hair["hair_overlay"] = overlay


func _apply_hair_color() -> void:
	var mi = _hair.get("hair")
	if mi is MeshInstance3D:
		var flat := _flat(_hair_color, 0.85)
		mi.material_override = _paper(_hair_color, PAPER_TILE_HAIR, 1.0) if _proc else flat
	var overlay = _hair.get("hair_overlay")
	if overlay is MeshInstance3D:
		overlay.material_override = _hair_overlay_mat(_hair_color)
		overlay.visible = paper_hair_strands or not _proc


## Procedural faces: a flat paper surface (paper_skin.gdshader) in `color`, its grain at
## `tile` face units per UV1 unit; `seed` keeps skin and hair grain apart.
func _paper(color: Color, tile: float, seed: float) -> ShaderMaterial:
	if _paper_shader == null:
		_paper_shader = load(PAPER_SKIN_SHADER) as Shader
	var mat := ShaderMaterial.new()
	mat.shader = _paper_shader
	mat.set_shader_parameter("fill_color", color)
	mat.set_shader_parameter("tile", tile)
	mat.set_shader_parameter("seed", seed)
	_paper_look().apply_to(mat)
	return mat


## The papier-mache surface in use (paper_surface, loaded from DEFAULT_PAPER_SURFACE once).
static func _paper_look() -> PaperSurface:
	if paper_surface == null:
		paper_surface = load(DEFAULT_PAPER_SURFACE) as PaperSurface
	if paper_surface == null:
		paper_surface = PaperSurface.new()
	return paper_surface


## The strand overlay: the base hair colour multiplied by a transparent strand texture,
## grown a hair's-breadth so it sits just proud of the flat base without z-fighting.
func _hair_overlay_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.lightened(0.06)
	mat.roughness = 0.7
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.uv1_scale = Vector3(HAIR_OVERLAY_UV, HAIR_OVERLAY_UV, 1.0)
	mat.grow = true
	mat.grow_amount = HAIR_OVERLAY_GROW
	var tex := load(HAIR_STRANDS) as Texture2D
	if tex != null:
		mat.albedo_texture = tex
	return mat


## Dress in a made suit: swap the top/bottom MODEL to the chosen styles (only when
## they change) and colour each piece. `shirt_mat` null falls back to off-white.
func set_outfit(
	jacket_mat: MaterialType,
	shirt_mat: MaterialType,
	trousers_mat: MaterialType,
	jacket_style := 0,
	pants_style := 0
) -> void:
	if jacket_style != _top_style or _top.is_empty():
		_swap_top(jacket_style)
	_apply_cloth(_top.get("jacket"), jacket_mat)
	if shirt_mat != null:
		_apply_cloth(_top.get("shirt"), shirt_mat)
	else:
		_apply_flat(_top.get("shirt"), DEFAULT_SHIRT, 0.6)

	_dress_extras()
	_show_extras(true)

	if pants_style != _bottom_style or _bottom.is_empty():
		_swap_bottom(pants_style)
	_apply_cloth(_bottom.get("pants"), trousers_mat)
	_restore_shoes()


## Street clothes worn on arrival: `outfit`'s own top, trousers and shoe models in its
## cloth and leather (a random outfit when null). An outfit without a top model falls
## back to the flat-colour look on the current suit meshes. set_outfit puts the suit
## back, with the base shoes in the wearer's own leather.
func wear_street(outfit: StreetOutfit = null) -> void:
	if outfit == null:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		outfit = Wardrobe.library().random_street_outfit(Enums.Gender.ANY, rng)
	if outfit == null or outfit.top == null or outfit.top.model == null:
		_wear_flat_street()
		return
	_wear_top(outfit.top)
	_top_style = STREET_STYLE
	_apply_cloth(_top.get("jacket"), outfit.outer_mat)
	_apply_cloth(_top.get("shirt"), outfit.inner_mat)
	if outfit.bottom != null and outfit.bottom.model != null:
		_bottom = _swap_part(_bottom, outfit.bottom)
		_bottom_style = STREET_STYLE
	_apply_cloth(_bottom.get("pants"), outfit.pants_mat)
	if outfit.shoe_model != null and outfit.shoe_model.model != null:
		_swap_shoes(outfit.shoe_model)
	_street_shoes = not outfit.shoes.is_empty()
	_paint_shoes(outfit.shoes if _street_shoes else _shoes)


## The fallback street look (an outfit with no models): muted flat colours on the
## current top/bottom, with the suit's pocket square taken off.
func _wear_flat_street() -> void:
	_apply_flat(_top.get("jacket"), CASUAL_TOPS[randi() % CASUAL_TOPS.size()], 0.85)
	_apply_flat(_top.get("shirt"), Color(0.9, 0.9, 0.88), 0.7)
	_apply_flat(_bottom.get("pants"), CASUAL_BOTTOMS[randi() % CASUAL_BOTTOMS.size()], 0.85)
	_show_extras(false)
	# The shirt mesh is only a collar and cuffs, so a hidden tie leaves a hole under the
	# collar. Until street clothes get their own models, the tie stays on in a muted
	# knit colour and the buttons stay, as on a blazer; only the pocket square goes.
	var tie = _top.get("tie")
	if tie is MeshInstance3D:
		tie.visible = true
		_apply_flat(tie, STREET_TIES[randi() % STREET_TIES.size()], 1.0)
	var buttons = _top.get("buttons")
	if buttons is MeshInstance3D:
		buttons.visible = true


## Flat materials on the top's small pieces: the tie in tie_color (outlined, like the
## other garments), gilt buttons and a white pocket square. A jacket swap brings fresh
## meshes with the model's own materials, so this runs after every swap.
func _dress_extras() -> void:
	_apply_flat(_top.get("tie"), _tie_color, 1.0)
	var buttons = _top.get("buttons")
	if buttons is MeshInstance3D:
		buttons.material_override = _flat(BUTTON_COLOR, 1.0)
	var square = _top.get("square")
	if square is MeshInstance3D:
		square.material_override = _flat(SQUARE_COLOR, 1.0)


func _show_extras(on: bool) -> void:
	for role: String in SUIT_EXTRAS:
		var mi = _top.get(role)
		if mi is MeshInstance3D:
			mi.visible = on


## Keep the wearer's own leather (see `shoes`); it shows at once unless a street
## outfit's shoes are on.
func _set_shoes(value: Dictionary) -> void:
	_shoes = ShoeMaterial.from_dict(value)
	if not _street_shoes:
		_paint_shoes(_shoes)


## One leather material, shared by both feet of the shoes worn now.
func _paint_shoes(value: Dictionary) -> void:
	var d := ShoeMaterial.from_dict(value)
	var mat := ShoeMaterial.build(d["color"], d["finish"], SHOE_UV_SCALE, true)
	for role in _shoe_slot:
		var mi = _shoe_slot[role]
		if mi is MeshInstance3D:
			mi.material_override = mat


## Back to the base pair in the wearer's own leather (after street clothes).
func _restore_shoes() -> void:
	if _shoe_part != null or _shoe_slot.is_empty():
		_swap_shoes(null)
	_street_shoes = false
	_paint_shoes(_shoes)


## Swap the shoe model; null puts the base pair back (the wardrobe's shoes 0).
func _swap_shoes(part: WardrobePart) -> void:
	_shoe_slot = _swap_part(_shoe_slot, part if part != null else Wardrobe.shoe(0))
	_shoe_part = part


func _swap_top(style: int) -> void:
	_wear_top(Wardrobe.top(style))
	_top_style = style


## Fill the top slot from `part`. A top with an "arms" role brings its own hands, so the
## base arms are set aside first (freeing the node name for the part's mesh); a top
## without one (the suits) gets the base arms back. Either way the hands take the skin.
func _wear_top(part: WardrobePart) -> void:
	_top = _clear(_top)
	var own_arms := part != null and part.model != null and part.roles.has("arms")
	_set_base_arms(not own_arms)
	_top = _swap_part({}, part)
	if own_arms and not _top.has("arms"):
		_set_base_arms(true)  # the model had no arms mesh after all
	_apply_skin()


## Put the base arms on the skeleton, or take them off (kept for later, not freed).
func _set_base_arms(on: bool) -> void:
	if _base_arms == null or _skel == null:
		return
	var worn := _base_arms.get_parent() == _skel
	if on and not worn:
		_skel.add_child(_base_arms)
	elif not on and worn:
		_skel.remove_child(_base_arms)


func _swap_bottom(style: int) -> void:
	_bottom = _swap_part(_bottom, Wardrobe.bottom(style))
	_bottom_style = style


## Clear a slot and fill it from `part`'s model (empty if the part has none).
func _swap_part(slot: Dictionary, part: WardrobePart) -> Dictionary:
	_clear(slot)
	if part != null and part.model != null:
		return _attach_from(part.model, part.roles)
	return {}


# --- Slot plumbing ---------------------------------------------------------


## Adopt the base model's baked-in meshes (already under the skeleton) into a slot.
func _adopt(roles: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for role in roles:
		var mi := find_child(roles[role], true, false)
		if mi is MeshInstance3D:
			out[role] = mi
	return out


## Pull the named meshes out of `model` and reparent them onto our skeleton. Their
## Skin binds by bone name; if the source rig names a bone differently (e.g. an
## imported head skinned to "head" while ours is "head_2"), we remap the binds by
## matching rest positions, so any same-geometry Rig_Medium .glb drops in as-is.
func _attach_from(model: PackedScene, roles: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if _skel == null or model == null:
		return out
	var inst := model.instantiate()
	var src_skel := inst.find_child("Skeleton3D", true, false) as Skeleton3D
	var remap := _bone_remap(src_skel)
	for role in roles:
		var mi := inst.find_child(roles[role], true, false)
		if mi is MeshInstance3D:
			mi.get_parent().remove_child(mi)
			mi.owner = null  # it leaves the source scene (no "owner inconsistent" warning)
			_skel.add_child(mi)
			mi.skeleton = NodePath("..")
			if not remap.is_empty() and src_skel != null:
				_rebind_skin(mi, src_skel, remap)
			out[role] = mi
	inst.queue_free()
	return out


## Map source-skeleton bone names -> our bone index, but only when some source bone
## name is missing from our skeleton (otherwise {} — the fast, no-op path). A missing
## name is matched to our bone at the same rest position (the rigs share geometry).
func _bone_remap(src: Skeleton3D) -> Dictionary:
	if src == null:
		return {}
	var needs := false
	for i in src.get_bone_count():
		if _skel.find_bone(src.get_bone_name(i)) < 0:
			needs = true
			break
	if not needs:
		return {}
	var map: Dictionary = {}
	for i in src.get_bone_count():
		var nm := src.get_bone_name(i)
		var j := _skel.find_bone(nm)
		if j < 0:
			j = _nearest_bone(_skel, _global_rest(src, i).origin)
		map[nm] = j
	return map


## Rewrite a reparented mesh's Skin binds to point at our bones (by the remap), so
## name- or index-bound skins both resolve correctly on the shared skeleton.
func _rebind_skin(mi: MeshInstance3D, src: Skeleton3D, remap: Dictionary) -> void:
	var skin := mi.skin
	if skin == null:
		return
	var s := skin.duplicate() as Skin
	for bi in s.get_bind_count():
		var bn := s.get_bind_name(bi)
		if bn == StringName():
			var bb := s.get_bind_bone(bi)
			if bb >= 0 and bb < src.get_bone_count():
				bn = src.get_bone_name(bb)
		if remap.has(bn):
			var dj: int = remap[bn]
			s.set_bind_bone(bi, dj)
			s.set_bind_name(bi, _skel.get_bone_name(dj))
	mi.skin = s


func _nearest_bone(sk: Skeleton3D, pos: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in sk.get_bone_count():
		var d := _global_rest(sk, i).origin.distance_to(pos)
		if d < best_d:
			best_d = d
			best = i
	return best


## A bone's rest transform in skeleton space (animation-independent), by walking rests
## up to the root — used to match bones between rigs by position.
func _global_rest(sk: Skeleton3D, bone: int) -> Transform3D:
	var t := Transform3D.IDENTITY
	var b := bone
	while b >= 0:
		t = sk.get_bone_rest(b) * t
		b = sk.get_bone_parent(b)
	return t


func _clear(slot: Dictionary) -> Dictionary:
	for role in slot:
		var mi = slot[role]
		if is_instance_valid(mi):
			# Detach synchronously so the node name is free before we add the
			# replacement (queue_free alone keeps the name occupied this frame,
			# which would make add_child rename the new mesh).
			if mi.get_parent() != null:
				mi.get_parent().remove_child(mi)
			mi.queue_free()
	return {}


func _apply_cloth(mi, mat: MaterialType) -> void:
	if mi is MeshInstance3D and mat != null:
		# Fabric tiled across the garment's metre-scale UVs + the dark element outline.
		mi.material_override = ClothMaterial.build(mat, CLOTH_UV_SCALE, true)


func _apply_flat(mi, color: Color, roughness: float) -> void:
	if mi is MeshInstance3D:
		var m := _flat(color, roughness)
		m.next_pass = ClothMaterial.outline_material()  # rim the shirt/collar too
		mi.material_override = m


func _flat(color: Color, _roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	# Fully matte: max roughness, no metal, no specular highlight or reflections.
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat
