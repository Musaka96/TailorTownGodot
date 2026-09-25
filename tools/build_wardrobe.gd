extends SceneTree

## Generates the editable wardrobe asset data/wardrobe/default_wardrobe.tres.
## Starts from WardrobeLibrary.make_default() (the base CHARTGEN head/hair/suit, shoes,
## street outfits + colour palettes), then AUTO-SCANS assets/characters/parts/*.glb.
## parts/glasses_<style>.glb become glasses parts; every other glb is a head+hair COMBO:
## its two meshes are split by height (face = lower, hair = higher) and appended as a
## matching head/hair pair at the SAME index, so a character always wears a head with
## its own hair (only the skin/hair COLOURS vary). Gender comes from
## the filename ("_f"/"female" -> FEMALE, "_m"/"male" -> MALE, else ANY). Adding a look
## is just: drop a Rig_Medium head+hair .glb into assets/characters/parts/ and rerun.
##   godot --headless --path . --script res://tools/build_wardrobe.gd

const OUT_PATH := "res://data/wardrobe/default_wardrobe.tres"
const PARTS_DIR := "res://assets/characters/parts"
## parts/glasses_<style>.glb are glasses (meshes `frames` + optional `lenses`), not heads.
const GLASSES_PREFIX := "glasses_"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/wardrobe"))
	var lib := WardrobeLibrary.make_default()
	_scan_parts(lib)
	var err := ResourceSaver.save(lib, OUT_PATH)
	if err == OK:
		print("build_wardrobe: wrote ", OUT_PATH)
		print(
			(
				(
					"  heads=%d hairs=%d tops=%d bottoms=%d shoes=%d street=%d glasses=%d"
					+ " skins=%d hair_colors=%d"
				)
				% [
					lib.heads.size(),
					lib.hairs.size(),
					lib.tops.size(),
					lib.bottoms.size(),
					lib.shoes.size(),
					lib.street_outfits.size(),
					lib.glasses.size(),
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
		if f.begins_with(GLASSES_PREFIX):
			_add_glasses(lib, ps, f)
			continue
		var pair := _detect_head_hair(ps)
		if pair.is_empty():
			print("build_wardrobe: skipped ", f, " (need a head+hair combo, >=2 meshes)")
			continue
		var g := _gender_from(f)
		var label := f.get_basename()
		# Appended together so heads[i] and hairs[i] are always the same combo.
		lib.heads.append(WardrobePart.make(label + " head", ps, {"head": pair["head"]}, g))
		lib.hairs.append(WardrobePart.make(label + " hair", ps, {"hair": pair["hair"]}, g))
		print("  + ", f, "  head=", pair["head"], " hair=", pair["hair"], " gender=", g)


## A glasses part keyed by its style (glasses_wire.glb -> "wire"), with a lenses role
## only when the glb has a `lenses` mesh.
func _add_glasses(lib: WardrobeLibrary, ps: PackedScene, fname: String) -> void:
	var inst := ps.instantiate()
	var roles := {}
	for role in ["frames", "lenses"]:
		if inst.find_child(role, true, false) is MeshInstance3D:
			roles[role] = role
	inst.free()
	if not roles.has("frames"):
		print("build_wardrobe: skipped ", fname, " (glasses need a `frames` mesh)")
		return
	var kind := fname.get_basename().trim_prefix(GLASSES_PREFIX)
	lib.glasses.append(WardrobePart.make(kind, ps, roles))
	print("  + ", fname, "  glasses=", kind, " roles=", roles.keys())


## Split a head+hair combo glb: meshes named `head` and `Hair` (any case) win; otherwise
## by AABB centre Y (face lower, hair higher).
## Returns {"head": name, "hair": name}, or {} if it has fewer than 2 meshes.
func _detect_head_hair(ps: PackedScene) -> Dictionary:
	var inst := ps.instantiate()
	var meshes := inst.find_children("*", "MeshInstance3D", true, false)
	var out := {}
	var named := {}
	for mi: MeshInstance3D in meshes:
		var key := String(mi.name).to_lower()
		if key in ["head", "hair"]:
			named[key] = mi.name
	if named.size() == 2:
		out = {"head": named["head"], "hair": named["hair"]}
	elif meshes.size() >= 2:
		var head_mi: MeshInstance3D = meshes[0]
		var hair_mi: MeshInstance3D = meshes[0]
		for mi: MeshInstance3D in meshes:
			var cy := mi.get_aabb().get_center().y
			if cy < head_mi.get_aabb().get_center().y:
				head_mi = mi
			if cy > hair_mi.get_aabb().get_center().y:
				hair_mi = mi
		out = {"head": head_mi.name, "hair": hair_mi.name}
	inst.free()
	return out


func _gender_from(fname: String) -> int:
	# Whole tokens only: "avatar_fringe_cap" must not read as "_f".
	var tokens := fname.get_basename().to_lower().replace("-", "_").split("_", false)
	if tokens.has("female") or tokens.has("f"):
		return Enums.Gender.FEMALE
	if tokens.has("male") or tokens.has("m"):
		return Enums.Gender.MALE
	return Enums.Gender.ANY
