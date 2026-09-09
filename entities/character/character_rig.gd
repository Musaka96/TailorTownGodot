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

# --- 2D face (cute animated eyes + mouth on the head) ----------------------
# Head bone the face rides on (KayKit Rig_Medium), and where the sprites sit in the
# skeleton's rest space (head front is ~z 0.44; tuned so they hug the face).
const FACE_BONE := "head_2"
const FACE_DIR := "res://assets/textures/faces/"
const EYE_POS := Vector3(0.0, 1.73, 0.47)
const MOUTH_POS := Vector3(0.0, 1.57, 0.47)
const EYE_PIXEL := 0.0058
const MOUTH_PIXEL := 0.0050
const BLINK_MIN := 2.4
const BLINK_MAX := 6.0

# Shared across every character so the textures load once.
static var _eyes_sf: SpriteFrames
static var _mouth_sf: SpriteFrames

var _pending := ""
var _oneshot_done := Callable()

var _skel: Skeleton3D
var _eyes: AnimatedSprite3D
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


# --- 2D face ---------------------------------------------------------------


## Mount cute eyes + mouth on the head bone. Billboard is OFF (the camera is fixed
## and characters turn away, so the face must rotate with the head, not the camera);
## double-sided OFF means it simply vanishes when they face away. Eyes blink on their
## own timer; the mouth flaps while set_talking(true).
func _build_face() -> void:
	if _skel == null:
		return
	var idx := _skel.find_bone(FACE_BONE)
	if idx < 0:
		return
	var attach := BoneAttachment3D.new()
	attach.name = "FaceAttach"
	attach.bone_name = FACE_BONE
	_skel.add_child(attach)
	var inv := _skel.get_bone_global_pose(idx).affine_inverse()
	_eyes = _face_sprite(_eyes_frames(), EYE_PIXEL, "open")
	_eyes.transform = inv * Transform3D(Basis(), EYE_POS)
	attach.add_child(_eyes)
	_mouth = _face_sprite(_mouth_frames(), MOUTH_PIXEL, "closed")
	_mouth.transform = inv * Transform3D(Basis(), MOUTH_POS)
	attach.add_child(_mouth)
	_eyes.animation_finished.connect(_on_blink_done)
	_blink = Timer.new()
	_blink.one_shot = true
	add_child(_blink)
	_blink.timeout.connect(_do_blink)
	_schedule_blink()


## The mouth flaps open/closed while a line is being said (called by the dialogue UI).
func set_talking(on: bool) -> void:
	if _mouth != null:
		_mouth.play("talk" if on else "closed")


func _face_sprite(frames: SpriteFrames, pixel: float, anim: String) -> AnimatedSprite3D:
	var s := AnimatedSprite3D.new()
	s.sprite_frames = frames
	s.pixel_size = pixel
	s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	s.shaded = false
	s.double_sided = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.play(anim)
	return s


func _schedule_blink() -> void:
	if _blink != null:
		_blink.start(randf_range(BLINK_MIN, BLINK_MAX))


func _do_blink() -> void:
	if _eyes != null:
		_eyes.play("blink")
	_schedule_blink()


func _on_blink_done() -> void:
	if _eyes != null and _eyes.animation == "blink":
		_eyes.play("open")


static func _eyes_frames() -> SpriteFrames:
	if _eyes_sf == null:
		_eyes_sf = SpriteFrames.new()
		_add_anim(_eyes_sf, "open", ["eyes_open"], 8.0, false)
		_add_anim(_eyes_sf, "blink", ["eyes_blink", "eyes_blink"], 14.0, false)
	return _eyes_sf


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


# --- Animation -------------------------------------------------------------


## Toggle the walk cycle vs idle (no-op if already there / mid one-shot gesture).
func set_moving(moving: bool) -> void:
	if _anim == null:
		return
	var want := "walk" if moving else "idle"
	if _anim.current_animation in ONE_SHOTS:
		_pending = want
		return
	if _anim.current_animation == want:
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
		var back := _pending if _pending != "" else "idle"
		_pending = ""
		_anim.play(back, 0.2)
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
