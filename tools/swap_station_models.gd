extends SceneTree

## One-off: puts the new worktable and sewing machine models (assets/models/stations/) into
## their station scenes in place of the old imported ones, with an UpgradeParts node to show
## the owned upgrades on them. Run once, headless, then commit the scenes:
##   godot --headless --path . --script res://tools/swap_station_models.gd
## (Owner, 2026-09-22: "I like them, replace them in game".)

const DIR := "res://assets/models/stations/"
## scene -> [new glb, the old model node to drop, where the new one sits in the station's
## space (over the old one's footprint), manifest key]
const SWAPS := {
	"res://stations/worktable/worktable.tscn":
	["worktable_v1.glb", "RadniSto", Vector3(0.03, 0, 0.31), "worktable"],
	"res://stations/sewing_machine/sewing_machine.tscn":
	["sewing_v1.glb", "MasinaZaSivenje", Vector3(0.07, 0, 0.3), "sewing"],
}
## The worktable's cloth now lies in the clear middle of the new top (the back of it holds
## the pattern paper and its weights, where the old slot was).
const WORKTABLE_SLOT := Vector3(0.03, 0.97, 0.31)
## The sewing table's collider, fitted to the new table (the old one sat 0.3 m too far back).
const SEWING_COL := [Vector3(0.07, 0.45, 0.3), Vector3(1.4, 0.9, 0.72)]


func _initialize() -> void:
	for path: String in SWAPS:
		_swap(path, SWAPS[path])
	print("swap_station_models: done")
	quit(0)


func _swap(path: String, spec: Array) -> void:
	var root: Node3D = (load(path) as PackedScene).instantiate()
	var old := root.get_node_or_null(str(spec[1]))
	if old != null:
		root.remove_child(old)
		old.free()
	var arm := root.get_node_or_null("Body/Arm")  # the old machine's stand-in arm block
	if arm != null:
		arm.get_parent().remove_child(arm)
		arm.free()
	var model: Node3D = (load(DIR + str(spec[0])) as PackedScene).instantiate()
	model.name = "Model"
	model.position = spec[2]
	root.add_child(model)
	model.owner = root
	# loaded here, not named: naming a class in a --script tool compiles it too early
	var parts: Node = (load("res://entities/scripts/upgrade_parts.gd") as GDScript).new()
	parts.name = "UpgradeParts"
	parts.set("manifest_key", str(spec[3]))
	root.add_child(parts)
	parts.owner = root
	if str(spec[3]) == "worktable":
		(root.get_node("Slot") as Node3D).position = WORKTABLE_SLOT
	else:
		var col := root.get_node("Body/TableCol") as CollisionShape3D
		col.position = SEWING_COL[0]
		var box := BoxShape3D.new()
		box.size = SEWING_COL[1]
		col.shape = box
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	print("swap_station_models: %s -> %s" % [path, error_string(err)])
	root.free()
