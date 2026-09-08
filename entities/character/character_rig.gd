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

# Casual colours for the placeholder street outfit (until street models exist).
const CASUAL_TOPS := [Color("6d7f9c"), Color("8a6d5b"), Color("5f7d5f"), Color("9c6d78")]
const CASUAL_BOTTOMS := [Color("39414f"), Color("5b4a3a"), Color("4a4a4a")]

# Fabric tiling across the mesh UVs (UV-mapped so the weave locks to the surface).
const CLOTH_UV_SCALE := 6.0

# One-off gestures that set_moving must not interrupt (they return to idle/walk).
const ONE_SHOTS := ["wave", "accept"]

var _pending := ""
var _oneshot_done := Callable()

var _skel: Skeleton3D
# Each slot maps role -> MeshInstance3D currently filling it.
var _top: Dictionary = {}
var _bottom: Dictionary = {}
var _hair: Dictionary = {}
# Currently-shown style/index, so we only re-instance a model when it changes.
var _top_style := 0
var _bottom_style := 0
var _hair_index := 0

@onready var _anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_skel = find_child("Skeleton3D", true, false) as Skeleton3D
	_top = _adopt(BAKED_TOP)
	_bottom = _adopt(BAKED_BOTTOM)
	_hair = _adopt(BAKED_HAIR)
	if _anim != null:
		_anim.animation_finished.connect(_on_finished)
		if not _anim.is_playing():
			_anim.play("idle")


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
	var item := Wardrobe.hair(index)
	if not item.is_empty():
		_hair = _attach_from(item["glb"], item["roles"])
	_hair_index = index


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
	var item := Wardrobe.top(style)
	if not item.is_empty():
		_top = _attach_from(item["glb"], item["roles"])
	_top_style = style


func _swap_bottom(style: int) -> void:
	_bottom = _clear(_bottom)
	var item := Wardrobe.bottom(style)
	if not item.is_empty():
		_bottom = _attach_from(item["glb"], item["roles"])
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


## Pull the named meshes out of `glb_path` and reparent them onto our skeleton.
## Their Skin binds by bone name, so on the shared Rig_Medium they animate as-is.
func _attach_from(glb_path: String, roles: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if _skel == null:
		return out
	var packed := load(glb_path) as PackedScene
	if packed == null:
		return out
	var inst := packed.instantiate()
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
