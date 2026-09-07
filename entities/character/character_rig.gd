class_name CharacterRig
extends Node3D

## Runtime controller for the shared character (built by tools/build_character.gd
## from CHARTGEN1 + KayKit Rig_Medium animations). Drives the AnimationPlayer
## (idle/walk/wave) and swaps per-part suit materials at runtime — jacket, shirt
## and trousers each get a UV-mapped cloth material, so the mirror menu can
## restyle the suit live. Skin parts (head, arms) take a flat colour. Parts not
## listed here (buttons, Hair, the left/right leg pieces) keep the model's own
## imported materials.

# CHARTGEN1 mesh parts grouped by what material they receive.
const SKIN_PARTS := ["head", "arms"]
const JACKET_PARTS := ["jacket"]
const SHIRT_PARTS := ["shirt"]
const PANTS_PARTS := ["legs"]

const DEFAULT_SKIN := Color(0.86, 0.72, 0.60)
const DEFAULT_SHIRT := Color(0.90, 0.90, 0.87)

# Fabric tiling across the mesh UVs. UV mapping (not triplanar) so the weave/
# pattern is locked to the surface and deforms with the animation instead of
# swimming. Tune if the tiling looks too dense/sparse for the character's UVs.
const CLOTH_UV_SCALE := 6.0

# One-off gestures that set_moving must not interrupt (they return to idle/walk).
const ONE_SHOTS := ["wave", "accept"]

var _pending := ""
var _oneshot_done := Callable()

@onready var _anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	if _anim != null:
		_anim.animation_finished.connect(_on_finished)
		if not _anim.is_playing():
			_anim.play("idle")


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


## Play a one-off greeting gesture, then return to what we were doing.
func wave() -> void:
	_play_once("wave", Callable())


## Play the happy "accepted the design" gesture; `done` fires when it finishes.
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


## Colour the exposed skin (head, hands, feet).
func set_palette(skin: Color) -> void:
	_apply(SKIN_PARTS, _flat(skin, 0.7))


## Dress the character. Jacket / shirt / trousers each take a triplanar cloth
## material from a MaterialType; pass null to leave a part alone (shirt falls back
## to a crisp off-white). Called on spawn and, later, live from the mirror menu.
func set_outfit(
	jacket_mat: MaterialType, shirt_mat: MaterialType, trousers_mat: MaterialType
) -> void:
	if jacket_mat != null:
		_apply(JACKET_PARTS, ClothMaterial.build(jacket_mat, CLOTH_UV_SCALE))
	if trousers_mat != null:
		_apply(PANTS_PARTS, ClothMaterial.build(trousers_mat, CLOTH_UV_SCALE))
	if shirt_mat != null:
		_apply(SHIRT_PARTS, ClothMaterial.build(shirt_mat, CLOTH_UV_SCALE))
	else:
		_apply(SHIRT_PARTS, _flat(DEFAULT_SHIRT, 0.6))


func _apply(part_names: Array, material: Material) -> void:
	for part_name in part_names:
		var node := find_child(part_name, true, false)
		if node is MeshInstance3D:
			node.material_override = material


func _flat(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat


func _on_finished(anim_name: String) -> void:
	if anim_name in ONE_SHOTS:
		var back := _pending if _pending != "" else "idle"
		_pending = ""
		_anim.play(back, 0.2)
		var done := _oneshot_done
		_oneshot_done = Callable()
		if done.is_valid():
			done.call()
