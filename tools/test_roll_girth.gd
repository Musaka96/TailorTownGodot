extends SceneTree

## A bolt is as fat as the cloth left on it: 20 m keeps the old 0.13 m radius, cutting
## makes it thinner, a loaded bolt comes back at its saved girth, and the mesh follows.
##   godot --headless --path . --script res://tools/test_roll_girth.gd

var _fails := 0


func _initialize() -> void:
	_run()


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails += 1


## Radius of the built mesh (the barrel's extent across the axis).
func _mesh_r(roll: Node) -> float:
	var mi: MeshInstance3D = roll.get_node("Mesh")
	var box := mi.mesh.get_aabb()
	return box.size.x * 0.5


func _run() -> void:
	await process_frame  # root isn't live during _initialize; _ready would never run
	var scene: PackedScene = load("res://entities/items/material_roll.tscn")
	var mat: Resource = load("res://data/materials/navy_worsted_pinstripe.tres")

	var roll: Node = scene.instantiate()
	roll.material = mat
	roll.remaining_length_m = 20.0
	root.add_child(roll)
	await process_frame
	_check(absf(roll.radius() - 0.13) < 0.002, "20 m bolt keeps the 0.13 m radius")
	_check(absf(_mesh_r(roll) - 0.13) < 0.003, "mesh matches the 20 m radius")
	_check(roll.radius_for(5.0) < 0.08 and roll.radius_for(5.0) > 0.06, "5 m is about 0.07")
	_check(roll.radius_for(40.0) > 0.17 and roll.radius_for(40.0) < 0.19, "40 m is about 0.18")
	_check(roll.radius_for(0.0) >= 0.045 - 0.0001, "an empty bolt stays wider than its tube")
	_check(roll.radius_for(500.0) <= 0.2, "a huge bolt is capped")

	var before: float = _mesh_r(roll)
	roll.cut(15.0)
	_check(roll.radius() < 0.08, "cutting 15 m off makes the bolt thinner")
	_check(_mesh_r(roll) < before - 0.04, "the mesh shrinks with the cut")

	var codec: GDScript = load("res://data/scripts/save_codec.gd")
	var loaded: Node = codec.item_from(codec.item_to(roll))
	root.add_child(loaded)
	await process_frame
	_check(absf(loaded.radius() - roll.radius()) < 0.001, "a loaded bolt keeps its girth")
	_check(absf(_mesh_r(loaded) - roll.radius()) < 0.003, "and its mesh is rebuilt to match")

	var full: Node = scene.instantiate()
	full.material = mat
	root.add_child(full)
	await process_frame
	_check(absf(full.radius() - full.radius_for(mat.roll_length_m)) < 0.001, "full bolt")
	full.material = load("res://data/materials/tan_linen_solid.tres")
	var mi: MeshInstance3D = full.get_node("Mesh")
	_check(mi.get_surface_override_material(0) != null, "swapping cloth rebuilds the barrel")

	print("test_roll_girth: " + ("ALL PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(1 if _fails > 0 else 0)
