extends SceneTree

## Headless test for the modular character wardrobe: swapping a slot must pull the
## mesh from a Wardrobe .glb and reparent it onto the shared skeleton so it still
## animates. Tops have real second models (style 1 = double-breasted); other slots
## with one library entry clamp, which still exercises the full reparent path (the
## slot is cleared and re-attached).
##   godot --headless --path . --script res://tools/test_wardrobe.gd

var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var rig: Node = load("res://entities/character/character_rig.tscn").instantiate()
	root.add_child(rig)
	await process_frame
	await process_frame

	var skel: Node = rig.find_child("Skeleton3D", true, false)
	_check(skel != null, "skeleton present")
	_check(_under(rig, "Hair", skel), "baked hair sits under the skeleton")
	_check(_under(rig, "jacket", skel), "baked jacket sits under the skeleton")

	# The library resolves to WardrobeParts with a model + roles.
	var part: WardrobePart = Wardrobe.hair(0)
	_check(part != null and part.model != null, "hair(0) resolves to a WardrobePart model")
	_check(not Wardrobe.library().skin_colors.is_empty(), "library has a skin palette")
	_check(not Wardrobe.library().hair_colors.is_empty(), "library has a hair-colour palette")

	# Force a hair reparent (index 1 clamps to the only entry but still swaps).
	rig.set_hair(1)
	rig.set_hair_color(Color(0.4, 0.2, 0.1))
	await process_frame
	_check(_under(rig, "Hair", skel), "hair reattached under the skeleton after swap")

	# Force a top + bottom model swap: style 1 is the double-breasted model.
	rig.set_outfit(null, null, null, 1, 1)
	await process_frame
	for part_name in ["jacket", "shirt", "legs", "buttons", "square", "tie"]:
		_check(_under(rig, part_name, skel), "%s reattached under the skeleton" % part_name)
	_check(
		_verts(rig.find_child("jacket", true, false)) == _verts(_source_jacket(1)),
		"style 1 wears the double-breasted jacket model"
	)
	_check(_extras_visible(rig, true), "a suit shows its buttons, pocket square and tie")
	rig.tie_color = Color(0.1, 0.2, 0.5)
	var tie := rig.find_child("tie", true, false) as MeshInstance3D
	var tie_mat := tie.material_override as StandardMaterial3D if tie != null else null
	_check(
		tie_mat != null and tie_mat.albedo_color.is_equal_approx(Color(0.1, 0.2, 0.5)),
		"tie_color recolours the tie"
	)

	# Street clothes drop the pocket square but keep the tie (it covers the hole under
	# the collar, the shirt mesh being only a collar and cuffs) and the buttons.
	rig.wear_street()
	await process_frame
	_check(
		_visible(rig, "square") == false and _visible(rig, "tie") and _visible(rig, "buttons"),
		"wear_street hides the pocket square, keeps the tie and buttons"
	)
	rig.set_outfit(null, null, null, 0, 0)
	await process_frame
	_check(
		_verts(rig.find_child("jacket", true, false)) == _verts(_source_jacket(0)),
		"style 0 swaps back to the single-breasted jacket model"
	)
	_check(_extras_visible(rig, true), "set_outfit shows them again")

	# The Tuxedo is listed but its top is a placeholder, so menus must skip it.
	var jacket := Enums.GarmentType.JACKET
	_check(Wardrobe.top(2) != null and Wardrobe.top(2).placeholder, "top 2 is a placeholder")
	_check(not Wardrobe.style_ready(jacket, 2), "the Tuxedo is not selectable")
	_check(Wardrobe.style_ready(jacket, 0) and Wardrobe.style_ready(jacket, 1), "SB/DB are")

	_finish()


func _visible(rig: Node, part_name: String) -> bool:
	var mi := rig.find_child(part_name, true, false) as MeshInstance3D
	return mi != null and mi.visible


func _extras_visible(rig: Node, want: bool) -> bool:
	for part_name in ["buttons", "square", "tie"]:
		var mi := rig.find_child(part_name, true, false) as MeshInstance3D
		if mi == null or mi.visible != want:
			return false
	return true


## The jacket mesh inside wardrobe top `style`'s source model.
func _source_jacket(style: int) -> MeshInstance3D:
	var inst := Wardrobe.top(style).model.instantiate()
	var mi := inst.find_child("jacket", true, false) as MeshInstance3D
	root.add_child(inst)  # freed with the tree at quit
	return mi


func _verts(node: Node) -> int:
	var mi := node as MeshInstance3D
	if mi == null or mi.mesh == null:
		return -1
	return mi.mesh.surface_get_array_len(0)


## True if a mesh named `name` exists and is a child of `skel`.
func _under(rig: Node, part_name: String, skel: Node) -> bool:
	var mi: Node = rig.find_child(part_name, true, false)
	return mi is MeshInstance3D and mi.get_parent() == skel


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("test_wardrobe: ALL PASS")
		quit(0)
	else:
		print("test_wardrobe: %d FAILURE(S)" % _failures.size())
		quit(1)
