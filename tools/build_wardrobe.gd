extends SceneTree

## Generates the editable wardrobe asset data/wardrobe/default_wardrobe.tres.
## Starts from WardrobeLibrary.make_default() (the base CHARTGEN head/hair/suit +
## colour palettes), then AUTO-SCANS assets/characters/parts/*.glb and appends a head
## part and a hair part for each — auto-detecting which mesh is the face (lower) and
## which is the hair (higher), and reading gender from the filename ("_f"/"female" ->
## FEMALE, "_m"/"male" -> MALE, else ANY). So adding a new head/hair to the game is
## just: drop a Rig_Medium .glb into assets/characters/parts/ and rerun this tool.
##   godot --headless --path . --script res://tools/build_wardrobe.gd

const OUT_PATH := "res://data/wardrobe/default_wardrobe.tres"
const PARTS_DIR := "res://assets/characters/parts"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/wardrobe"))
	var lib := WardrobeLibrary.make_default()
	_scan_parts(lib)
	var err := ResourceSaver.save(lib, OUT_PATH)
	if err == OK:
		print("build_wardrobe: wrote ", OUT_PATH)
		print(
			(
				"  heads=%d hairs=%d tops=%d bottoms=%d skins=%d hair_colors=%d"
				% [
					lib.heads.size(),
					lib.hairs.size(),
					lib.tops.size(),
					lib.bottoms.size(),
					lib.skin_colors.size(),
					lib.hair_colors.size(),
				]
			)
		)
		quit(0)
	else:
		printerr("build_wardrobe: save failed, error ", err)
		quit(1)


## Append a head + hair WardrobePart for every .glb in the parts folder.
func _scan_parts(lib: WardrobeLibrary) -> void:
	var dir := DirAccess.open(PARTS_DIR)
	if dir == null:
		print("build_wardrobe: no parts folder at ", PARTS_DIR, " (skipping scan)")
		return
	var files := dir.get_files()
	files.sort()
	for f in files:
		if f.get_extension().to_lower() != "glb":
			continue
		var ps := load(PARTS_DIR + "/" + f) as PackedScene
		if ps == null:
			continue
		var pair := _detect_head_hair(ps)
		if pair.is_empty():
			print("build_wardrobe: skipped ", f, " (need >=2 skinned meshes)")
			continue
		var g := _gender_from(f)
		var label := f.get_basename()
		lib.heads.append(WardrobePart.make(label + " head", ps, {"head": pair["head"]}, g))
		lib.hairs.append(WardrobePart.make(label + " hair", ps, {"hair": pair["hair"]}, g))
		print("  + ", f, "  head=", pair["head"], " hair=", pair["hair"], " gender=", g)


## The face mesh sits lower on the head than the hair, so classify by AABB centre Y:
## highest = hair, lowest = head. Returns {"head": name, "hair": name} or {} if <2.
func _detect_head_hair(ps: PackedScene) -> Dictionary:
	var inst := ps.instantiate()
	var meshes := inst.find_children("*", "MeshInstance3D", true, false)
	var out := {}
	if meshes.size() >= 2:
		var hair_mi: MeshInstance3D = null
		var head_mi: MeshInstance3D = null
		var hi := -INF
		var lo := INF
		for mi: MeshInstance3D in meshes:
			var cy := mi.get_aabb().get_center().y
			if cy > hi:
				hi = cy
				hair_mi = mi
			if cy < lo:
				lo = cy
				head_mi = mi
		out = {"head": head_mi.name, "hair": hair_mi.name}
	inst.free()
	return out


func _gender_from(fname: String) -> int:
	var n := fname.to_lower()
	if n.contains("female") or n.contains("_f"):
		return Enums.Gender.FEMALE
	if n.contains("_male") or n.contains("_m"):
		return Enums.Gender.MALE
	return Enums.Gender.ANY
