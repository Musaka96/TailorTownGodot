extends SceneTree

## Headless test of the cut-paper cast (FaceCast): every cast surname has a preset file;
## a name always gets the same face; a named cast member walks in wearing their own face,
## hair colour and glasses, the glasses scaled across to their eye spacing; the player is
## J1; a regular's face survives a Clientele save and restore; and a look saved before
## faces were remembered (no face_style) still dresses, with the face the name picks.
##   godot --headless --path . --script res://tools/test_face_cast.gd
## Exit code is non-zero on any failed assertion.

const CAST_SCRIPT := "res://data/scripts/face_cast.gd"
const PREF_SCRIPT := "res://data/scripts/customer_preference.gd"
const STYLE_DIR := "res://data/face_styles/"

var _failures: Array[String] = []
var _manager: Node
## Loaded at run time: the classes lean on autoloads a --script can't see at compile time.
var _cast: GDScript
var _pref_cls: GDScript


func _initialize() -> void:
	_run()


func _run() -> void:
	_cast = load(CAST_SCRIPT)
	_pref_cls = load(PREF_SCRIPT)
	_registry()
	change_scene_to_file("res://main.tscn")
	await process_frame
	await process_frame
	var ui: Node = root.get_node("UI")
	if ui.newspaper != null:
		ui.newspaper.close()
	_manager = get_first_node_in_group("customer_manager")
	_player_is_j1()
	_cast_walk_in()
	await _pince_nez()
	_round_trip()
	_old_look()
	_finish()


## Every preset the registry names exists; the pick from a name is stable and is one of
## the customer presets; unknown preset names fall back to J1.
func _registry() -> void:
	var missing := PackedStringArray()
	var names: Array = _cast.CUSTOMER_PRESETS + [_cast.PLAYER, _cast.MENTOR]
	for surname: String in _cast.BY_NAME:
		names.append(_cast.BY_NAME[surname][0])
	for preset: String in names:
		if not ResourceLoader.exists(STYLE_DIR + preset + ".tres"):
			missing.append(preset)
	_check(missing.is_empty(), "every cast preset has a file %s" % ", ".join(missing))
	_check(_cast.preset_for("Mr. Dimmock") == "paper_dimmock", "Mr. Dimmock wears paper_dimmock")
	_check(
		_cast.preset_for("Mrs. Applegarth") == "paper_pettigrew",
		"Mrs. Applegarth shares Mr. Pettigrew's face"
	)
	_check(_cast.preset_for("Dr. Vance") == "paper_vance", "Dr. Vance wears paper_vance")
	var stable := true
	var spread := {}
	for nm: String in _pref_cls.FIRST_NAMES:
		var a: String = _cast.preset_for(nm)
		stable = stable and a == _cast.preset_for(nm) and a in _cast.CUSTOMER_PRESETS
		spread[a] = true
	_check(stable, "preset_for is the same every call and always a customer preset")
	_check(spread.size() >= 5, "the names spread over the presets (%d used)" % spread.size())
	# Pinned: a change here means every regular in every save changes face.
	_check(
		_cast.preset_for("Mr. Ellison") == "paper_noble",
		"preset_for hashes the same way it always has"
	)
	_check(
		(_cast.style("no_such_face") as Resource).resource_path == STYLE_DIR + "paper_j1.tres",
		"an unknown preset falls back to J1"
	)


func _player_is_j1() -> void:
	var player: Node = get_first_node_in_group("player")
	var rig: Node = player.get_node("Model") if player != null else null
	var face: Resource = rig.get("face_style") if rig != null else null
	_check(
		face != null and face.resource_path == STYLE_DIR + "paper_j1.tres", "the player wears J1"
	)


## A walk-in named "Ms. Portobello" wears her face, her auburn hair and tortoise wire
## glasses, fitted to her close-set eyes: the rims centred across on them, hanging
## GlassesFit.GLASSES_HANG below them on the nose, never stretched; rims shrunk below
## GlassesFit.TEMPLE_MIN_SCALE lose their temples (a pince-nez), others keep them.
func _cast_walk_in() -> void:
	var pref: Resource = _pref_cls.random_pref(RandomNumberGenerator.new(), "Ms. Portobello")
	var cust := _spawn_with(pref)
	var rig: Node = cust.get_node("Rig")
	var face: Resource = rig.get("face_style")
	_check(cust.face_style == "paper_portobello", "a cast walk-in gets their preset")
	_check(
		face != null and face.resource_path == STYLE_DIR + "paper_portobello.tres",
		"and the rig wears it"
	)
	_check(cust.hair_color.is_equal_approx(Color("5e2618")), "with the cast hair colour")
	_check(cust.glasses == "wire" and cust.glasses_color == "tortoise", "and the cast glasses")
	var meshes: Array = rig.get("_glasses_meshes")
	var off := Vector2.INF
	var stretch := INF
	var arms := "(no glasses)"
	if not meshes.is_empty():
		var mi: MeshInstance3D = meshes[0]
		var bind: Transform3D = mi.get_meta("bind")
		var t: Transform3D = bind.affine_inverse() * mi.transform
		stretch = absf(t.basis.x.length() - t.basis.y.length())
		var lens := GlassesFit.measure(mi.mesh, bind)
		var eye := GlassesFit.eye_point(face as FaceStyle, rig.get("_face_frame"))
		if not lens.is_empty():
			off = (lens.c as Vector2) - eye + Vector2(0.0, GlassesFit.GLASSES_HANG)
		arms = _temple_check(mi, face as FaceStyle, rig.get("_face_frame"))
	_check(stretch < 1e-4, "the glasses are not stretched across (%.4f)" % stretch)
	_check(arms == "", "temples kept or dropped by the rim scale %s" % arms)
	_check(
		off.length() < 0.005, "the lens centre hangs GLASSES_HANG below the eye (off by %s m)" % off
	)
	cust.free()


## Dr. Vance's dot eyes sit too close for the wire rims on most heads: on head 3 the rims
## shrink below GlassesFit.TEMPLE_MIN_SCALE and the frames lose their temples.
func _pince_nez() -> void:
	var pref: Resource = _pref_cls.random_pref(RandomNumberGenerator.new(), "Dr. Vance")
	var cust := _spawn_with(pref)
	var rig: Node = cust.get_node("Rig")
	rig.call("set_head", 3)
	await process_frame
	var meshes: Array = rig.get("_glasses_meshes")
	var face: FaceStyle = rig.get("face_style")
	var frame: FaceFrame = rig.get("_face_frame")
	var grow := INF
	var arms := "(no glasses)"
	if not meshes.is_empty():
		var mi: MeshInstance3D = meshes[0]
		var lens := GlassesFit.measure(mi.get_meta("src"), mi.get_meta("bind"))
		var eye := GlassesFit.eye_point(face, frame)
		grow = GlassesFit.rim_grow(lens, eye.x, GlassesFit.eye_radius(face, frame))
		arms = _temple_check(mi, face, frame)
	_check(grow < GlassesFit.TEMPLE_MIN_SCALE, "Dr. Vance's rims shrink on head 3 (%.2f)" % grow)
	_check(arms == "", "so his glasses sit as a pince-nez, no temples %s" % arms)
	cust.free()


## "" when the fitted frames keep their temples exactly when the rim scale is at least
## GlassesFit.TEMPLE_MIN_SCALE (a shrunk fit shows no triangle behind the hinge plane).
func _temple_check(mi: MeshInstance3D, face: FaceStyle, frame: FaceFrame) -> String:
	var bind: Transform3D = mi.get_meta("bind")
	var lens := GlassesFit.measure(mi.get_meta("src"), bind)
	var eye := GlassesFit.eye_point(face, frame)
	var grow := GlassesFit.rim_grow(lens, eye.x, GlassesFit.eye_radius(face, frame))
	var behind := 0
	for s in mi.mesh.get_surface_count():
		var arrays: Array = mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx := PackedInt32Array(range(verts.size()))  # unindexed: every vertex in turn
		if arrays[Mesh.ARRAY_INDEX] != null:
			idx = arrays[Mesh.ARRAY_INDEX]
		for t in range(0, idx.size() - 2, 3):
			for k in 3:
				if (bind * verts[idx[t + k]]).z <= lens.hinge:
					behind += 1
					break
	var bare := grow < GlassesFit.TEMPLE_MIN_SCALE
	if (behind == 0) == bare:
		return ""
	return "(scale %.2f, %d temple triangles)" % [grow, behind]


## A regular's face_style survives Clientele.save_state -> bytes -> restore.
func _round_trip() -> void:
	var clientele: Node = root.get_node("Clientele")
	clientele.reset()
	var pref: Resource = _pref_cls.random_pref(RandomNumberGenerator.new(), "Mr. Ellison")
	var cust := _spawn_with(pref)
	var face: String = cust.face_style
	clientele.note_customer(cust)
	cust.free()
	var saved: Variant = bytes_to_var(var_to_bytes(clientele.save_state()))
	clientele.reset()
	clientele.restore(saved)
	var look: Dictionary = clientele.look("Mr. Ellison")
	_check(face != "" and str(look.get("face_style", "")) == face, "face_style round-trips")
	clientele.reset()


## A look from before faces were saved: the face comes from the name, the same each
## time; a cast member's old random look gives way to their own face and hair.
func _old_look() -> void:
	var look := {
		"skin": Color(0.8, 0.6, 0.5),
		"head": 0,
		"hair": 0,
		"hair_color": Color.BLACK,
		"eyes": "green",
		"glasses": "round",
		"gender": 1,
	}
	var faces := []
	for _i in 2:
		var pref: Resource = _pref_cls.random_pref(RandomNumberGenerator.new(), "Mr. Oldsave")
		var cust := _spawn_with(pref)
		_manager.call("_dress_as", cust, look, "Mr. Oldsave")
		var face: Resource = cust.get_node("Rig").get("face_style")
		faces.append(face.resource_path if face != null else "")
		_check(
			cust.face_style == _cast.preset_for("Mr. Oldsave"), "an old look gets the name's face"
		)
		_check(cust.glasses == "wire", "and its old glasses")
		cust.free()
	_check(faces[0] != "" and faces[0] == faces[1], "the same face on every visit")
	var pref: Resource = _pref_cls.random_pref(RandomNumberGenerator.new(), "Mr. Dimmock")
	var dim := _spawn_with(pref)
	_manager.call("_dress_as", dim, look, "Mr. Dimmock")
	_check(dim.face_style == "paper_dimmock", "an old look of Mr. Dimmock wears his face")
	_check(dim.hair_color.is_equal_approx(Color("2a1d15")), "and his dark hair")
	_check(dim.glasses == "", "and never glasses")
	dim.free()


## A customer dressed for `pref` the way _spawn does it.
func _spawn_with(pref: Resource) -> Node:
	var cust: Node = _manager.call("_spawn", Vector3.ZERO, false)
	cust.preference = pref
	_manager.call("_dress", cust)
	return cust


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("test_face_cast: ALL PASS")
		quit(0)
	else:
		print("test_face_cast: %d FAILURE(S)" % _failures.size())
		quit(1)
