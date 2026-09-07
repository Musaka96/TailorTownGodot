class_name CharacterRig
extends Node3D

## Runtime controller for the shared character (built by tools/build_character.gd
## from CHAR1 + KayKit Rig_Medium animations). Drives the AnimationPlayer
## (idle/walk/wave) and swaps per-part suit materials at runtime — jacket, shirt
## and trousers each get a triplanar cloth material, so the mirror menu can
## restyle the suit live. Skin parts (head, hands, feet) take a flat colour.

# CHAR1 mesh parts grouped by what material they receive.
const SKIN_PARTS := [
	"Mannequin_Medium_Head",
	"Mannequin_Medium_ArmLeft_001",
	"Mannequin_Medium_ArmRight_001",
	"Mannequin_Medium_LegLeft_001",
	"Mannequin_Medium_LegRight_001",
]
const JACKET_PARTS := [
	"Mannequin_Medium_Body",
	"Mannequin_Medium_ArmLeft",
	"Mannequin_Medium_ArmRight",
]
const SHIRT_PARTS := ["Mannequin_Medium_Body_001"]
const PANTS_PARTS := ["Mannequin_Medium_LegLeft", "Mannequin_Medium_LegRight"]

const DEFAULT_SKIN := Color(0.86, 0.72, 0.60)
const DEFAULT_SHIRT := Color(0.90, 0.90, 0.87)

var _pending := ""

@onready var _anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	if _anim != null:
		_anim.animation_finished.connect(_on_finished)
		if not _anim.is_playing():
			_anim.play("idle")


## Toggle the walk cycle vs idle (no-op if already there / mid-wave).
func set_moving(moving: bool) -> void:
	if _anim == null:
		return
	var want := "walk" if moving else "idle"
	if _anim.current_animation == "wave":
		_pending = want
		return
	if _anim.current_animation == want:
		return
	_anim.play(want, 0.2)


## Play a one-off greeting gesture, then return to what we were doing.
func wave() -> void:
	if _anim == null or not _anim.has_animation("wave"):
		return
	_pending = _anim.current_animation
	_anim.play("wave", 0.15)


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
		_apply(JACKET_PARTS, ClothMaterial.build_triplanar(jacket_mat, 3.0))
	if trousers_mat != null:
		_apply(PANTS_PARTS, ClothMaterial.build_triplanar(trousers_mat, 3.0))
	if shirt_mat != null:
		_apply(SHIRT_PARTS, ClothMaterial.build_triplanar(shirt_mat, 3.5))
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
	if anim_name == "wave":
		var back := _pending if _pending != "" else "idle"
		_pending = ""
		_anim.play(back, 0.2)
