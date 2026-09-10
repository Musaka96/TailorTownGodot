extends SceneTree

## Generates the editable wardrobe asset data/wardrobe/default_wardrobe.tres.
## Starts from WardrobeLibrary.make_default() (the base CHARTGEN head/hair/suit +
## colour palettes), then AUTO-SCANS assets/characters/parts/*.glb and appends parts.
## Adding a head/hair to the game is just: drop a Rig_Medium .glb into
## assets/characters/parts/ and rerun this tool. The filename decides what it holds:
##   - "hair" in the name (and not "head")        -> hair-only part
##   - "head" or "face" in the name (and not hair) -> head-only part
##   - otherwise, a 2+-mesh glb is a head+hair COMBO (face = lower mesh, hair = higher)
## Gender comes from the name too ("_f"/"female" -> FEMALE, "_m"/"male" -> MALE, else ANY).
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
		var found := _detect_parts(ps, _kind_from_name(f))
		if found.is_empty():
			print("build_wardrobe: skipped ", f, " (no skinned meshes found)")
			continue
		var g := _gender_from(f)
		var label := f.get_basename()
		if found.has("head"):
			lib.heads.append(WardrobePart.make(label + " head", ps, {"head": found["head"]}, g))
		if found.has("hair"):
			lib.hairs.append(WardrobePart.make(label + " hair", ps, {"hair": found["hair"]}, g))
		print("  + ", f, "  ", found, " gender=", g)


## What a filename says the glb holds: "head", "hair", or "combo" (auto).
func _kind_from_name(fname: String) -> String:
	var n := fname.to_lower()
	var has_hair := n.contains("hair")
	var has_head := n.contains("head") or n.contains("face")
	if has_hair and not has_head:
		return "hair"
	if has_head and not has_hair:
		return "head"
	return "combo"


## Resolve the mesh(es) to use. A combo glb (2+ meshes) splits by AABB centre Y —
## the face sits lower than the hair. A head-/hair-only glb takes its representative
## mesh (lowest for head, highest for hair). Returns {"head": name} and/or {"hair": name}.
func _detect_parts(ps: PackedScene, kind: String) -> Dictionary:
	var inst := ps.instantiate()
	var meshes := inst.find_children("*", "MeshInstance3D", true, false)
	var out := {}
	if not meshes.is_empty():
		var lowest: MeshInstance3D = meshes[0]
		var highest: MeshInstance3D = meshes[0]
		for mi: MeshInstance3D in meshes:
			var cy := mi.get_aabb().get_center().y
			if cy < lowest.get_aabb().get_center().y:
				lowest = mi
			if cy > highest.get_aabb().get_center().y:
				highest = mi
		if kind == "head":
			out = {"head": lowest.name}
		elif kind == "hair":
			out = {"hair": highest.name}
		elif meshes.size() >= 2:  # combo
			out = {"head": lowest.name, "hair": highest.name}
		else:  # single mesh, no name hint: guess by absolute height
			var key := "hair" if highest.get_aabb().get_center().y > 1.68 else "head"
			out = {key: highest.name}
	inst.free()
	return out


func _gender_from(fname: String) -> int:
	var n := fname.to_lower()
	if n.contains("female") or n.contains("_f"):
		return Enums.Gender.FEMALE
	if n.contains("_male") or n.contains("_m"):
		return Enums.Gender.MALE
	return Enums.Gender.ANY
