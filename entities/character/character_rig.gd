class_name CharacterRig
extends Node3D

## Runtime controller for the shared character (built by tools/build_character.gd
## from CHARTGEN1 + KayKit Rig_Medium animations). Drives the AnimationPlayer
## (idle/walk/wave/accept) and manages a modular wardrobe: the head and arms are
## fixed (skin), while HAIR, the suit TOP (jacket + shirt) and BOTTOM (trousers)
## are swappable slots. Each slot's mesh is pulled from a Wardrobe entry's .glb and
## reparented onto the shared skeleton — because every option is skinned to the
## same Rig_Medium, the animations drive it with no retargeting. Changing a suit
## style therefore changes the actual model, not just the colour.

# Arms are always the base skin mesh (never swapped); the head is swappable now.
const SKIN_ARMS := "arms"
# The base model's default meshes per slot (adopted on _ready as style/index 0).
const BAKED_HEAD := {"head": "head"}
const BAKED_TOP := {"jacket": "jacket", "shirt": "shirt"}
const BAKED_BOTTOM := {"pants": "legs"}
const BAKED_HAIR := {"hair": "Hair"}

# Two-layer hair: a flat base-colour mesh with a transparent strand-detail copy laid
# just over it (grown slightly so it never z-fights). Swap the PNG for real hair art.
const HAIR_STRANDS := "res://assets/textures/hair/strands.png"
const HAIR_OVERLAY_UV := 5.0
const HAIR_OVERLAY_GROW := 0.004

const DEFAULT_SKIN := Color(0.86, 0.72, 0.60)
const DEFAULT_SHIRT := Color(0.90, 0.90, 0.87)
const DEFAULT_HAIR := Color(0.14, 0.11, 0.09)

# Casual colours for the placeholder street outfit (until street models exist).
const CASUAL_TOPS := [Color("6d7f9c"), Color("8a6d5b"), Color("5f7d5f"), Color("9c6d78")]
const CASUAL_BOTTOMS := [Color("39414f"), Color("5b4a3a"), Color("4a4a4a")]

# Fabric tiling across the mesh UVs (UV-mapped so the weave locks to the surface). Worn
# suits get a dark inverted-hull outline (next_pass) that reads each garment part apart.
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
## Glasses overlays a customer may wear ("" = none), keyed to the sliced sprite name.
const GLASSES_KINDS := {"sun": "glasses_sun", "round": "glasses_round"}
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
var _glasses: Sprite3D
var _eye_color := "brown"
var _glasses_kind := ""  # "", "sun" or "round"; applied once the face is built
var _nose_index := 0  # which nose_N sprite (see assets/textures/faces/)
var _mouth_index := 0  # which mouth_N sprite
var _talk: Tween  # scale-pulse while talking
var _blink: Timer
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

@onready var _anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_skel = find_child("Skeleton3D", true, false) as Skeleton3D
	_head = _adopt(BAKED_HEAD)
	_top = _adopt(BAKED_TOP)
	_bottom = _adopt(BAKED_BOTTOM)
	_hair = _adopt(BAKED_HAIR)
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
	if _tree == null:
		return
	_loco = move_toward(_loco, _loco_target, LOCO_BLEND_SPEED * delta)
	_carry_amt = move_toward(_carry_amt, _carry_target, CARRY_BLEND_SPEED * delta)
	_loco_speed = move_toward(_loco_speed, _loco_speed_target, LOCO_SPEED_BLEND * delta)
	_tree.set("parameters/loco/blend_amount", _loco)
	_tree.set("parameters/carry/blend_amount", _carry_amt)
	_tree.set("parameters/loco_ts/scale", _loco_speed)


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
	_eye_l = _sprite(attach, _eye_tex(), false)
	_eye_r = _sprite(attach, _eye_tex(), true)
	_brow_l = _sprite(attach, _tex("brow"), false)
	_brow_r = _sprite(attach, _tex("brow"), true)
	_nose = _sprite(attach, _tex("nose_%d" % _nose_index), false)
	_mouth = _sprite(attach, _tex("mouth_%d" % _mouth_index), false)
	_glasses = _sprite(attach, null, false)
	# Name them so tools (the char preview gizmo) can find the element to manipulate.
	_eye_l.name = "eye_l"
	_brow_l.name = "brow_l"
	_nose.name = "nose"
	_mouth.name = "mouth"
	_glasses.name = "glasses"
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
	_place_one(_glasses, layout, "glasses", base)


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


## The mouth flaps open/closed while a line is being said (called by the dialogue UI).
func set_talking(on: bool) -> void:
	if _mouth == null:
		return
	if _talk != null and _talk.is_valid():
		_talk.kill()
	if on:
		_talk = create_tween().set_loops()
		_talk.tween_property(_mouth, "scale:y", 1.7, 0.09)
		_talk.tween_property(_mouth, "scale:y", 1.0, 0.09)
	else:
		_mouth.scale.y = 1.0


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
## break) and glasses ("sun" / "round", or "" for none) — the per-customer face look.
func set_face_look(eye_color: String, glasses: String, nose := -1, mouth := -1) -> void:
	_eye_color = eye_color if eye_color in EYE_COLORS else "brown"
	_glasses_kind = glasses
	if nose >= 0:
		_set_nose(nose)
	if mouth >= 0:
		_set_mouth(mouth)
	if not _is_blinking():
		_set_eye_tex(_eye_tex())
	_apply_glasses()


## Show/hide the glasses overlay for the stored kind. Safe before the face is built
## (the builder calls it again), so spawn-time set_face_look() never misses.
func _apply_glasses() -> void:
	if _glasses == null:
		return
	if GLASSES_KINDS.has(_glasses_kind):
		_glasses.texture = _tex(GLASSES_KINDS[_glasses_kind])
		_glasses.visible = true
	else:
		_glasses.visible = false


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
	_apply_skin()
	# Load this head/combo's own face profile so each head carries its own tuning.
	_layout = FaceProfiles.load_or_default().layout_for(index)
	apply_layout(_layout)


func _apply_skin() -> void:
	var mat := _flat(_skin_color, 0.7)
	var head_mi = _head.get("head")
	if head_mi is MeshInstance3D:
		head_mi.material_override = mat
	var arms := find_child(SKIN_ARMS, true, false)
	if arms is MeshInstance3D:
		arms.material_override = _flat(_skin_color, 0.7)


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
		mi.material_override = _flat(_hair_color, 0.85)
	var overlay = _hair.get("hair_overlay")
	if overlay is MeshInstance3D:
		overlay.material_override = _hair_overlay_mat(_hair_color)


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

	if pants_style != _bottom_style or _bottom.is_empty():
		_swap_bottom(pants_style)
	_apply_cloth(_bottom.get("pants"), trousers_mat)


## Placeholder street/casual look worn on arrival: muted flat colours on the
## current top/bottom. When real street models are imported, swap models here.
func wear_street() -> void:
	_apply_flat(_top.get("jacket"), CASUAL_TOPS[randi() % CASUAL_TOPS.size()], 0.85)
	_apply_flat(_top.get("shirt"), Color(0.9, 0.9, 0.88), 0.7)
	_apply_flat(_bottom.get("pants"), CASUAL_BOTTOMS[randi() % CASUAL_BOTTOMS.size()], 0.85)


func _swap_top(style: int) -> void:
	_top = _clear(_top)
	var part := Wardrobe.top(style)
	if part != null and part.model != null:
		_top = _attach_from(part.model, part.roles)
	_top_style = style


func _swap_bottom(style: int) -> void:
	_bottom = _clear(_bottom)
	var part := Wardrobe.bottom(style)
	if part != null and part.model != null:
		_bottom = _attach_from(part.model, part.roles)
	_bottom_style = style


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
		# UV-mapped fabric (follows the mesh UVs) + the dark element outline.
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
