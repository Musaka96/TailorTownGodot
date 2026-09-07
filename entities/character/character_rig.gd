class_name CharacterRig
extends Node3D

## Shared toon character rig (built by tools/build_character.gd). Drives its own
## AnimationPlayer and exposes a tiny API so the player and customers can switch
## between idle / walk and play a one-off wave. Recolour per character with
## set_palette(). AC-style rigid segments — no skinning.

var _pending := ""

@onready var _anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	if _anim != null:
		_anim.animation_finished.connect(_on_finished)
		if not _anim.is_playing():
			_anim.play("idle")


## Toggle the walk cycle vs idle (no-op if already in that state / mid-wave).
func set_moving(moving: bool) -> void:
	if _anim == null:
		return
	var want := "walk" if moving else "idle"
	if _anim.current_animation == "wave":
		_pending = want
		return
	if _anim.current_animation == want:
		return
	_anim.play(want, 0.15)


## Play a friendly wave, then return to whatever we were doing.
func wave() -> void:
	if _anim == null:
		return
	_pending = _anim.current_animation
	_anim.play("wave", 0.1)


## Recolour the person: skin (face/hands) and hair. Suit cloth is set separately
## via set_outfit(); shirt/tie/shoes/eyes keep their built colours.
func set_palette(skin: Color, hair: Color) -> void:
	var cols := {"skin": skin, "hair": hair}
	for mesh in _meshes():
		var slot: String = mesh.get_meta("slot")
		if cols.has(slot):
			var mat := StandardMaterial3D.new()
			mat.albedo_color = cols[slot]
			mat.roughness = 0.85
			mesh.material_override = mat


## Dress the character in a real suit: the jacket (torso + sleeves + lapels) and
## trousers use the same dynamic cloth material (fabric weave + pattern + colour)
## as the garment parts, so NPCs are wearing "our" fabrics.
func set_outfit(jacket_mat: MaterialType, trousers_mat: MaterialType) -> void:
	var jacket_cloth := ClothMaterial.build(jacket_mat, 1.2) if jacket_mat != null else null
	var trousers_cloth := ClothMaterial.build(trousers_mat, 1.2) if trousers_mat != null else null
	for mesh in _meshes():
		var slot: String = mesh.get_meta("slot")
		if slot == "jacket" and jacket_cloth != null:
			mesh.material_override = jacket_cloth
		elif slot == "trousers" and trousers_cloth != null:
			mesh.material_override = trousers_cloth


func _meshes() -> Array:
	var out: Array = []
	_collect(self, out)
	return out


func _collect(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.has_meta("slot"):
			out.append(child)
		_collect(child, out)


func _on_finished(anim_name: String) -> void:
	if anim_name == "wave":
		var back := _pending if _pending != "" else "idle"
		_pending = ""
		_anim.play(back, 0.15)
