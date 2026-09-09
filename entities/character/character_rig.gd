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

# Always-present skin meshes (never swapped).
const SKIN_PARTS := ["head", "arms"]
# The base model's default meshes per slot (adopted on _ready as style/index 0).
const BAKED_TOP := {"jacket": "jacket", "shirt": "shirt"}
const BAKED_BOTTOM := {"pants": "legs"}
const BAKED_HAIR := {"hair": "Hair"}

const DEFAULT_SKIN := Color(0.86, 0.72, 0.60)
const DEFAULT_SHIRT := Color(0.90, 0.90, 0.87)
const DEFAULT_HAIR := Color(0.14, 0.11, 0.09)

# Casual colours for the placeholder street outfit (until street models exist).
const CASUAL_TOPS := [Color("6d7f9c"), Color("8a6d5b"), Color("5f7d5f"), Color("9c6d78")]
const CASUAL_BOTTOMS := [Color("39414f"), Color("5b4a3a"), Color("4a4a4a")]

# Fabric tiling across the mesh UVs (UV-mapped so the weave locks to the surface).
const CLOTH_UV_SCALE := 6.0

# One-off gestures that set_moving must not interrupt (they return to idle/walk).
const ONE_SHOTS := ["wave", "accept"]

# --- Carrying --------------------------------------------------------------
# A carried item hangs off a point parented to the right-hand bone, so it moves
# with the hand through the holding animation and turns with the character. The
# offset seats the item into the hands (tuned against the Holding_A pose).
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
const BLINK_MIN := 2.4
const BLINK_MAX := 6.0
const BLINK_TIME := 0.11

# Shared across every character so the mouth frames load once.
static var _mouth_sf: SpriteFrames

var _pending := ""
var _oneshot_done := Callable()
var _carrying := false
var _moving := false
var _carry_hold: Node3D

var _skel: Skeleton3D
var _layout: FaceLayout
var _head_inv := Transform3D.IDENTITY
var _eye_l: Sprite3D
var _eye_r: Sprite3D
var _brow_l: Sprite3D
var _brow_r: Sprite3D
var _nose: Sprite3D
var _mouth: AnimatedSprite3D
var _blink: Timer
# Each slot maps role -> MeshInstance3D currently filling it.
var _top: Dictionary = {}
var _bottom: Dictionary = {}
var _hair: Dictionary = {}
# Currently-shown style/index, so we only re-instance a model when it changes.
var _top_style := 0
var _bottom_style := 0
var _hair_index := 0
# Tint applied to the hair mesh (kept so it survives a hairstyle swap).
var _hair_color := DEFAULT_HAIR

@onready var _anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_skel = find_child("Skeleton3D", true, false) as Skeleton3D
	_top = _adopt(BAKED_TOP)
	_bottom = _adopt(BAKED_BOTTOM)
	_hair = _adopt(BAKED_HAIR)
	if _anim != null:
		# Install the animation set from the editable asset (shared, cached), so
		# changing data/animations/default_animations.tres takes effect next run.
		if _anim.has_animation_library(""):
			_anim.remove_animation_library("")
		_anim.add_animation_library("", CharAnims.library())
		_anim.animation_finished.connect(_on_finished)
		if not _anim.is_playing():
			_anim.play("idle")
	_build_face()
	_build_carry()


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
	_layout = FaceLayout.load_or_default()
	_head_inv = _skel.get_bone_global_pose(idx).affine_inverse()
	var attach := BoneAttachment3D.new()
	attach.name = "FaceAttach"
	attach.bone_name = FACE_BONE
	_skel.add_child(attach)
	_eye_l = _sprite(attach, _tex("eye"), false)
	_eye_r = _sprite(attach, _tex("eye"), true)
	_brow_l = _sprite(attach, _tex("brow"), false)
	_brow_r = _sprite(attach, _tex("brow"), true)
	_nose = _sprite(attach, _tex("nose"), false)
	_mouth = _mouth_sprite(attach)
	apply_layout(_layout)
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
	_place(_eye_l, -layout.eye_gap * 0.5, layout.eye_y, layout.eye_px)
	_place(_eye_r, layout.eye_gap * 0.5, layout.eye_y, layout.eye_px)
	_place(_brow_l, -layout.brow_gap * 0.5, layout.brow_y, layout.brow_px)
	_place(_brow_r, layout.brow_gap * 0.5, layout.brow_y, layout.brow_px)
	_place(_nose, 0.0, layout.nose_y, layout.nose_px)
	_place(_mouth, 0.0, layout.mouth_y, layout.mouth_px)


## The mouth flaps open/closed while a line is being said (called by the dialogue UI).
func set_talking(on: bool) -> void:
	if _mouth != null:
		_mouth.play("talk" if on else "closed")


func _place(node: Node3D, x: float, y_off: float, px: float) -> void:
	if node == null or _layout == null:
		return
	var pos := Vector3(x, _layout.head_y + y_off, _layout.face_z)
	node.transform = _head_inv * Transform3D(Basis(), pos)
	node.pixel_size = px


func _sprite(parent: Node, tex: Texture2D, mirror: bool) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.flip_h = mirror
	_face_flags(s)
	parent.add_child(s)
	return s


func _mouth_sprite(parent: Node) -> AnimatedSprite3D:
	var s := AnimatedSprite3D.new()
	s.sprite_frames = _mouth_frames()
	_face_flags(s)
	s.play("closed")
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
	_set_eye_tex(_tex("eye"))


func _set_eye_tex(tex: Texture2D) -> void:
	if _eye_l != null:
		_eye_l.texture = tex
	if _eye_r != null:
		_eye_r.texture = tex


static func _tex(sprite_name: String) -> Texture2D:
	return load(FACE_DIR + sprite_name + ".png") as Texture2D


static func _mouth_frames() -> SpriteFrames:
	if _mouth_sf == null:
		_mouth_sf = SpriteFrames.new()
		_add_anim(_mouth_sf, "closed", ["mouth_closed"], 8.0, false)
		_add_anim(
			_mouth_sf, "talk", ["mouth_closed", "mouth_mid", "mouth_open", "mouth_mid"], 9.0, true
		)
	return _mouth_sf


static func _add_anim(
	sf: SpriteFrames, anim: String, files: Array, speed: float, loop: bool
) -> void:
	sf.add_animation(anim)
	sf.set_animation_speed(anim, speed)
	sf.set_animation_loop(anim, loop)
	for f: String in files:
		sf.add_frame(anim, load(FACE_DIR + f + ".png") as Texture2D)


# --- Carrying --------------------------------------------------------------


## The point a carried item attaches to — parented to the hand bone, so the item
## follows the hand and turns with the character. Null until the rig is ready.
func carry_point() -> Node3D:
	return _carry_hold


## Whether the character is holding something; switches the holding pose on/off.
func set_carrying(on: bool) -> void:
	if on == _carrying:
		return
	_carrying = on
	_refresh_locomotion()


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


## Report walking vs standing; the actual clip also depends on whether we're
## carrying (see _refresh_locomotion).
func set_moving(moving: bool) -> void:
	if moving == _moving:
		return
	_moving = moving
	_refresh_locomotion()


## Pick the base clip from the current state: the holding pose while carrying,
## otherwise walk/idle. A one-shot gesture defers the change until it finishes.
func _refresh_locomotion() -> void:
	if _anim == null:
		return
	var want := "carry" if _carrying else ("walk" if _moving else "idle")
	if _anim.current_animation in ONE_SHOTS:
		_pending = want
		return
	if _anim.current_animation == want or not _anim.has_animation(want):
		return
	_anim.play(want, 0.2)


func wave() -> void:
	_play_once("wave", Callable())


func celebrate(done := Callable()) -> void:
	_play_once("accept", done)


func _play_once(anim_name: String, done: Callable) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		if done.is_valid():
			done.call()
		return
	if not (_anim.current_animation in ONE_SHOTS):
		_pending = _anim.current_animation
	_oneshot_done = done
	_anim.play(anim_name, 0.15)


func _on_finished(anim_name: String) -> void:
	if anim_name in ONE_SHOTS:
		_pending = ""
		_refresh_locomotion()  # return to carry / walk / idle per current state
		var done := _oneshot_done
		_oneshot_done = Callable()
		if done.is_valid():
			done.call()


# --- Wardrobe --------------------------------------------------------------


## Colour the exposed skin (head, arms).
func set_palette(skin: Color) -> void:
	for part_name in SKIN_PARTS:
		var node := find_child(part_name, true, false)
		if node is MeshInstance3D:
			node.material_override = _flat(skin, 0.7)


## Swap to hairstyle `index` from the Wardrobe (no-op if already shown).
func set_hair(index: int) -> void:
	if index == _hair_index and not _hair.is_empty():
		return
	_hair = _clear(_hair)
	var part := Wardrobe.hair(index)
	if part != null and part.model != null:
		_hair = _attach_from(part.model, part.roles)
	_hair_index = index
	_apply_hair_color()


## Tint the hair (kept and re-applied whenever the hairstyle mesh is swapped).
func set_hair_color(color: Color) -> void:
	_hair_color = color
	_apply_hair_color()


func _apply_hair_color() -> void:
	var mi = _hair.get("hair")
	if mi is MeshInstance3D:
		mi.material_override = _flat(_hair_color, 0.85)


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


## Pull the named meshes out of `model` and reparent them onto our skeleton.
## Their Skin binds by bone name, so on the shared Rig_Medium they animate as-is.
func _attach_from(model: PackedScene, roles: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if _skel == null or model == null:
		return out
	var inst := model.instantiate()
	for role in roles:
		var mi := inst.find_child(roles[role], true, false)
		if mi is MeshInstance3D:
			mi.get_parent().remove_child(mi)
			_skel.add_child(mi)
			mi.skeleton = NodePath("..")
			out[role] = mi
	inst.queue_free()
	return out


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
		mi.material_override = ClothMaterial.build(mat, CLOTH_UV_SCALE)


func _apply_flat(mi, color: Color, roughness: float) -> void:
	if mi is MeshInstance3D:
		mi.material_override = _flat(color, roughness)


func _flat(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat
