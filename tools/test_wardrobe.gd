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

	# Street clothes are their own models: the outfit's jacket (outer layer), shirt,
	# trousers and shoes, in its cloth and leather, with no tie, square or buttons.
	rig.shoes = {"color": "oxblood", "finish": "calf"}  # the wearer's own leather
	var base_shoes := rig.find_child("shoes", true, false)
	var street: StreetOutfit = Wardrobe.street_outfit(0)
	_check(street != null and street.top != null, "the library has street outfits")
	rig.wear_street(street)
	await process_frame
	_check(
		_verts(rig.find_child("jacket", true, false)) == _verts(_source_mesh(street.top, "jacket")),
		"wear_street wears the street outfit's jacket model"
	)
	_check(
		_verts(rig.find_child("legs", true, false)) == _verts(_source_mesh(street.bottom, "legs")),
		"wear_street wears the street outfit's trousers"
	)
	for part_name in ["tie", "square", "buttons"]:
		_check(
			rig.find_child(part_name, true, false) == null, "street clothes have no " + part_name
		)
	var street_shoes := rig.find_child("shoes", true, false)
	_check(
		street_shoes != null and street_shoes != base_shoes and _under(rig, "shoes", skel),
		"the street outfit swaps in its own shoe model"
	)
	_check(_leather(rig).is_equal_approx(_dye("white")), "in the outfit's leather")
	rig.shoes = {"color": "tan", "finish": "calf"}  # a new own pair stays off the sneakers
	_check(_leather(rig).is_equal_approx(_dye("white")), "own leather waits")

	# A suit after street clothes: the suit models come back, the base pair of shoes too,
	# in the wearer's own leather.
	rig.set_outfit(null, null, null, 1, 0)
	await process_frame
	_check(
		_verts(rig.find_child("jacket", true, false)) == _verts(_source_jacket(1)),
		"set_outfit after wear_street restores the suit jacket model"
	)
	_check(_extras_visible(rig, true), "and its buttons, pocket square and tie")
	_check(
		(
			_verts(rig.find_child("shoes", true, false))
			== _verts(_source_mesh(Wardrobe.shoe(0), "shoes"))
		),
		"the base pair of shoes is back"
	)
	_check(_leather(rig).is_equal_approx(_dye("tan")), "in the wearer's leather")
	rig.set_outfit(null, null, null, 0, 0)
	await process_frame
	_check(
		_verts(rig.find_child("jacket", true, false)) == _verts(_source_jacket(0)),
		"style 0 swaps back to the single-breasted jacket model"
	)
	await _check_regular()

	# The Tuxedo is listed but its top is a placeholder, so menus must skip it.
	var jacket := Enums.GarmentType.JACKET
	_check(Wardrobe.top(2) != null and Wardrobe.top(2).placeholder, "top 2 is a placeholder")
	_check(not Wardrobe.style_ready(jacket, 2), "the Tuxedo is not selectable")
	_check(Wardrobe.style_ready(jacket, 0) and Wardrobe.style_ready(jacket, 1), "SB/DB are")

	_finish()


## A regular's street outfit is remembered with their look (and survives a save) and
## comes back on the next visit.
func _check_regular() -> void:
	var clientele := root.get_node("Clientele")
	var last := Wardrobe.library().street_outfits.size() - 1
	var scene := load("res://entities/customer/customer.tscn") as PackedScene
	var cust: Node = scene.instantiate()
	root.add_child(cust)
	# By path: the class name drags autoload-only scripts into this --script compile.
	var pref: Resource = load("res://data/scripts/customer_preference.gd").new()
	pref.display_name = "Mr. Test Regular"
	cust.set("preference", pref)
	cust.set("street_index", last)
	clientele.note_customer(cust)
	clientele.restore(clientele.save_state())
	var look: Dictionary = clientele.look(pref.display_name)
	_check(int(look.get("street", -1)) == last, "the look dict keeps the street outfit index")
	var again: Node = scene.instantiate()
	root.add_child(again)
	await process_frame
	again.set("preference", pref)
	again.call("wear_street")
	var manager: Node = load("res://entities/customer/customer_manager.gd").new()
	manager.call("_dress_as", again, look, pref.display_name)
	await process_frame
	_check(int(again.get("street_index")) == last, "a regular gets the same outfit index back")
	var want := _source_mesh(Wardrobe.street_outfit(last).top, "jacket")
	_check(_verts(again.find_child("jacket", true, false)) == _verts(want), "and wears it")
	manager.free()
	clientele.reset()


## A ShoeMaterial dye, loaded by path (the class name pulls Config-dependent scripts
## into this --script compile).
func _dye(id: String) -> Color:
	return load("res://data/scripts/shoe_material.gd").COLORS[id]


## The leather colour on the shoes the rig wears now.
func _leather(rig: Node) -> Color:
	var mi := rig.find_child("shoes", true, false) as MeshInstance3D
	var sm := mi.material_override as ShaderMaterial if mi != null else null
	if sm == null:
		return Color(0, 0, 0, 0)
	return sm.get_shader_parameter("leather_color")


## The mesh named `mesh_name` inside a wardrobe part's source model.
func _source_mesh(part: WardrobePart, mesh_name: String) -> MeshInstance3D:
	var inst := part.model.instantiate()
	root.add_child(inst)  # freed with the tree at quit
	return inst.find_child(mesh_name, true, false) as MeshInstance3D


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
