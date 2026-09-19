extends SceneTree

## Headless test for the shop-look recolour system (docs/SHOP_LOOKS.md): loads the v6
## shop gltf, attaches a ShopLookApplier the same way main.gd does, applies every shipped
## look and checks the wall/wainscot/floor/drape slots each match a surface and that the
## materials actually change between looks.
##   godot --headless --path . --script res://tools/test_shop_looks.gd

const SHOP_GLTF := "res://IMPORT/town_kit/export/v6/tailor_shop_v6.gltf"
const REQUIRED_SLOTS := ["wall", "wainscot", "floor", "drape"]

var _failures: Array[String] = []


func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var shop: Node3D = load(SHOP_GLTF).instantiate()
	world.add_child(shop)

	var applier := ShopLookApplier.attach(world)
	_check(applier != null, "attach() finds the v6 shop and returns an applier")
	if applier == null:
		_finish()
		return
	_check(
		applier.looks.size() >= 6,
		"default look list loads at least 6 presets (%d)" % applier.looks.size()
	)
	_check(
		applier.looks.size() > 0 and applier.looks[0].id == &"fern_damask",
		"fern_damask is index 0 (the default look)"
	)

	# One probe surface per slot: the first mesh/surface whose BAKED material matches
	# that slot's alias, found once (independent of whatever override apply() sets).
	var probes: Dictionary = {}
	for slot_key: String in ShopLookApplier.SLOT_ALIASES:
		probes[slot_key] = _find_probe(shop, slot_key)
		_check(not probes[slot_key].is_empty(), "found a v6 surface for slot '%s'" % slot_key)

	var seen: Dictionary = {}  # slot -> Array[Material] across looks
	for i in applier.looks.size():
		var look: ShopLook = applier.looks[i]
		applier.apply(i)
		_check(applier.current == i, "apply(%d) sets current" % i)
		for slot_key in REQUIRED_SLOTS:
			_check(
				applier.matched_slots().has(slot_key),
				"look '%s' matches slot '%s'" % [look.id, slot_key]
			)
		for slot_key: String in probes:
			var probe: Array = probes[slot_key]
			if probe.is_empty():
				continue
			var mi: MeshInstance3D = probe[0]
			var mat := mi.get_active_material(probe[1])
			if not seen.has(slot_key):
				seen[slot_key] = []
			(seen[slot_key] as Array).append(mat)

	for slot_key: String in REQUIRED_SLOTS:
		var mats: Array = seen.get(slot_key, [])
		var unique := {}
		for m in mats:
			unique[m] = true
		_check(unique.size() > 1, "slot '%s' actually changes material between looks" % slot_key)

	# apply_id / next / previous / get_look round-trip.
	applier.apply_id(&"oxblood")
	_check(applier.get_look().id == &"oxblood", "apply_id() finds a look by id")
	applier.apply(0)
	applier.next()
	_check(applier.current == 1, "next() advances")
	applier.previous()
	_check(applier.current == 0, "previous() goes back")

	# Robustness: an applier with no looks warns instead of crashing.
	var empty := ShopLookApplier.new()
	empty.looks = []
	world.add_child(empty)
	empty.apply(0)
	_check(true, "apply() on an empty look list does not crash")
	empty.queue_free()

	_finish()


## First MeshInstance3D + surface index under `shop` whose baked (non-override)
## material name matches `slot_key`'s aliases. [] if none found.
func _find_probe(shop: Node, slot_key: String) -> Array:
	var aliases: Array = ShopLookApplier.SLOT_ALIASES[slot_key]
	for node in shop.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh := mi.mesh if mi != null else null
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			var name := mat.resource_name if mat != null else ""
			if aliases.has(name):
				return [mi, s]
	return []


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("test_shop_looks: ALL PASS")
		quit(0)
	else:
		print("test_shop_looks: %d FAILURE(S)" % _failures.size())
		quit(1)
