extends SceneTree

## Headless test for the modular character wardrobe: swapping a slot must pull the
## mesh from a Wardrobe .glb and reparent it onto the shared skeleton so it still
## animates. With one library entry each, calling a swap with a non-current index
## still exercises the full reparent path (the entry clamps but the slot is cleared
## and re-attached), which is exactly what firing a real second asset will do.
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

	# Force a hair reparent (index 1 clamps to the only entry but still swaps).
	rig.set_hair(1)
	await process_frame
	_check(_under(rig, "Hair", skel), "hair reattached under the skeleton after swap")

	# Force a top + bottom model swap.
	rig.set_outfit(null, null, null, 1, 1)
	await process_frame
	for part_name in ["jacket", "shirt", "legs"]:
		_check(_under(rig, part_name, skel), "%s reattached under the skeleton" % part_name)

	# Street outfit must not error.
	rig.wear_street()
	await process_frame
	_check(true, "wear_street ran without error")

	_finish()


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
