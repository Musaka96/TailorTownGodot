extends SceneTree

## Review sheet for glasses size variants: the cast's procedural paper faces (the same rig
## set-up and framing as shot_face_head.gd's cast_heads.png) wearing the glasses parts from
## variant folders exported by tools/blender/tripo_glasses.py --front-scale. NOT headless:
##   godot --path . --script res://tools/shot_glasses_variants.gd [-- --glasses-dir=<dir>]
## --label=<name> names a single folder's row and suffixes the files (sheet_<name>.png), e.g.
##   -- --glasses-dir=assets/characters/parts --label=v75   (the shipped parts)
## --glasses-dir (default res://.dev/glasses_variants) is either one variant folder (it holds
## glasses_<style>.glb) or a folder of variant folders (VARIANTS order first, then any other
## sub-folder by name). The glbs load at runtime (GLTFDocument, no import needed) and stand
## in for the wardrobe's glasses parts for this run only; nothing is saved to the library.
## Writes to IMPORT/CHARREWORK/report/glasses_variants/ (git-ignored):
##   sheet.png  rows = variants; per character a portrait (head about 500 px) and the
##              dialogue thumbnail (head about 140 px) beside it
##   side.png   rows = variants; one character turned 30 / 60 / 90 degrees (temple fit)

const RIG_SCENE := "res://entities/character/character_rig.tscn"
const RIG_SCRIPT := "res://entities/character/character_rig.gd"
const SUIT := "res://data/materials/navy_worsted_pinstripe.tres"
const STYLE_DIR := "res://data/face_styles/"
const DEFAULT_DIR := "res://.dev/glasses_variants"
const VARIANTS := ["v100", "v85", "v75", "v65", "vlow"]
# row labels: the --front-scale each variant was exported with (W in x, H in z)
const VARIANT_SCALES := {
	"v100": "1.00 x 1.00",
	"v85": "0.85 x 0.80",
	"v75": "0.75 x 0.70",
	"v65": "0.65 x 0.60",
	"vlow": "0.90 x 0.60",
}
const HEAD := "tripo_head_tl"  # the cast sheet's head
# name, preset, hair colour, glasses style, frame colour (cast colours from shot_face_head.gd)
const CAST := [
	["Mr. Pettigrew", "paper_pettigrew", Color("e9e4da"), "round", "gold"],
	["Ms. Portobello", "paper_portobello", Color("5e2618"), "wire", "tortoise"],
	["Mr. Dimmock", "paper_dimmock", Color("2a1d15"), "square", "black"],
	["Dr. Vance", "paper_vance", Color("15110f"), "halfmoon", "silver"],
]
const SIDE_WHO := 0  # CAST index for side.png
const SIDE_ANGLES := [30.0, 60.0, 90.0]
const OUT_DIR := "res://IMPORT/CHARREWORK/report/glasses_variants"
const SKIN := Color(0.86, 0.72, 0.60)
const DIST := 2.2
const SIZE := Vector2i(900, 900)
const PORTRAIT := 600  # cast_heads.png framing, drawn at 600 px: the head is about 500 px
const DIALOGUE := 200  # as cast_heads.png: the head is about 140 px
const SIDE_CELL := 400
const ROW_LABEL_W := 150
const LABEL_H := 26
const PAPER := Color("f7f1e6")
const INK := Color("3a2418")

var _rig: Node3D  # CharacterRig (untyped: the class pulls in autoloads a --script lacks)
var _vp: SubViewport
var _cam: Camera3D
var _head_y := 1.64
var _stock := {}  # glasses style -> the wardrobe's own WardrobePart


func _initialize() -> void:
	var rig_script: Variant = load(RIG_SCRIPT)
	rig_script.procedural_faces = true
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var world := Node3D.new()
	_vp.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.55, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 0.95)
	env.ambient_light_energy = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -32, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	_rig = (load(RIG_SCENE) as PackedScene).instantiate() as Node3D
	world.add_child(_rig)
	_head_y = FaceProfiles.load_or_default().layout_for(0).head_y
	_cam = Camera3D.new()
	_cam.fov = 35
	world.add_child(_cam)
	_cam.look_at_from_position(Vector3(0, _head_y, DIST), Vector3(0, _head_y, 0.4), Vector3.UP)
	_cam.current = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var suit := load(SUIT) as MaterialType
	_rig.set_palette(SKIN)
	_rig.set_outfit(suit, null, suit, 0, 0)
	(_rig.get("_blink") as Timer).stop()  # no random blink mid-capture
	var dir := DEFAULT_DIR
	var run_label := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--label="):
			run_label = a.trim_prefix("--label=")
		if a.begins_with("--glasses-dir="):
			dir = a.trim_prefix("--glasses-dir=")
			if not dir.begins_with("res://") and not dir.is_absolute_path():
				dir = "res://" + dir
	var variants := _variant_dirs(dir)
	if run_label != "" and variants.size() == 1:
		variants[0][0] = run_label
	if variants.is_empty():
		push_error("shot_glasses_variants: no glasses_*.glb under %s" % dir)
		quit(1)
		return
	var lib := Wardrobe.library()
	for kind in lib.glasses_kinds():
		_stock[kind] = lib.glasses_part(kind)
	var head := _find_head(HEAD)
	if head < 0:
		push_error("shot_glasses_variants: no head %s" % HEAD)
		quit(1)
		return
	_rig.call("set_head", head)
	_rig.call("set_hair", head)
	_rig.set_palette(SKIN)
	var sheet := []  # [image, position, label, label width]
	var side := []
	var w_char := PORTRAIT + DIALOGUE
	for r in variants.size():
		var v: Array = variants[r]
		_use_variant(v[1])
		var y := r * (PORTRAIT + LABEL_H)
		sheet.append([null, Vector2(0, y), _row_label(v[0]), ROW_LABEL_W])
		for c in CAST.size():
			await _dress(CAST[c])
			var x := ROW_LABEL_W + c * w_char
			var label := "%s / %s %s" % [CAST[c][0], CAST[c][4], CAST[c][3]]
			sheet.append([await _grab(PORTRAIT), Vector2(x, y), label, PORTRAIT])
			var img := await _grab(DIALOGUE)
			var dy := (PORTRAIT - DIALOGUE) / 2
			sheet.append([img, Vector2(x + PORTRAIT, y + dy), "dialogue", DIALOGUE])
		await _dress(CAST[SIDE_WHO])
		var sy := r * (SIDE_CELL + LABEL_H)
		side.append([null, Vector2(0, sy), _row_label(v[0]), ROW_LABEL_W])
		for c in SIDE_ANGLES.size():
			_rig.rotation_degrees.y = SIDE_ANGLES[c]
			await _pose(4)
			var pos := Vector2(ROW_LABEL_W + c * SIDE_CELL, sy)
			side.append(
				[
					await _grab(SIDE_CELL),
					pos,
					"%s %d deg" % [CAST[SIDE_WHO][0], SIDE_ANGLES[c]],
					SIDE_CELL
				]
			)
		_rig.rotation_degrees.y = 0.0
	var rows := variants.size()
	await _save(
		sheet,
		Vector2i(ROW_LABEL_W + CAST.size() * w_char, rows * (PORTRAIT + LABEL_H)),
		"sheet%s.png" % ("" if run_label == "" else "_" + run_label)
	)
	await _save(
		side,
		Vector2i(ROW_LABEL_W + SIDE_ANGLES.size() * SIDE_CELL, rows * (SIDE_CELL + LABEL_H)),
		"side%s.png" % ("" if run_label == "" else "_" + run_label)
	)
	for kind: String in _stock:  # hand the library its own parts back
		_swap_part(kind, _stock[kind])
	quit(0)


## [[name, {style: PackedScene}], ...]: `dir` itself when it holds glasses_*.glb, else its
## sub-folders (VARIANTS order first).
func _variant_dirs(dir: String) -> Array:
	var own := _load_set(dir)
	if not own.is_empty():
		return [[dir.get_file(), own]]
	var names: Array[String] = []
	for n in VARIANTS:
		if DirAccess.dir_exists_absolute(dir.path_join(n)):
			names.append(n)
	var more := DirAccess.get_directories_at(dir)
	more.sort()
	for n in more:
		if not names.has(n):
			names.append(n)
	var out := []
	for n in names:
		var glb_set := _load_set(dir.path_join(n))
		if not glb_set.is_empty():
			out.append([n, glb_set])
			print("variant %s: %s" % [n, ", ".join(glb_set.keys())])
	return out


## style -> PackedScene for every glasses_<style>.glb in `dir`, loaded with GLTFDocument.
func _load_set(dir: String) -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at(dir):
		if not (f.begins_with("glasses_") and f.ends_with(".glb")):
			continue
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(dir.path_join(f), state) != OK:
			push_error("shot_glasses_variants: cannot read %s" % dir.path_join(f))
			continue
		var scene := doc.generate_scene(state)
		_own_all(scene, scene)
		var packed := PackedScene.new()
		packed.pack(scene)
		scene.free()
		out[f.trim_prefix("glasses_").trim_suffix(".glb")] = packed
	return out


func _own_all(node: Node, top: Node) -> void:
	for ch in node.get_children():
		ch.owner = top
		_own_all(ch, top)


## Point each wardrobe glasses style at this variant's model (a copy of the stock part).
func _use_variant(glb_set: Dictionary) -> void:
	for kind: String in _stock:
		var part: WardrobePart = (_stock[kind] as WardrobePart).duplicate()
		if glb_set.has(kind):
			part.model = glb_set[kind]
		_swap_part(kind, part)


func _swap_part(kind: String, part: WardrobePart) -> void:
	var lib := Wardrobe.library()
	for i in lib.glasses.size():
		if lib.glasses[i] != null and lib.glasses[i].display_name == kind:
			lib.glasses[i] = part


## One cast member: hair, face preset, glasses (taken off first so the new model mounts).
func _dress(who: Array) -> void:
	_rig.call("set_hair_color", who[2])
	_rig.call("set_face_look", "brown", "")
	_rig.call("set_face_look", "brown", who[3])
	_rig.set("glasses_color", who[4])
	_rig.set("face_style", load(STYLE_DIR + String(who[1]) + ".tres") as FaceStyle)
	await _pose(4)


## The resting face, settled (as shot_face_head.gd's _pose("neutral")).
func _pose(frames: int) -> void:
	_rig.call("_proc_expression", "")
	_rig.call("_set_dial", _rig.call("_rest", "lid"), "lid", FaceStyle.Element.EYE)
	_rig.call("set_talking", false)
	await create_timer(0.3).timeout  # the reset tween settles (lids differ per preset)
	await create_timer(frames / 60.0).timeout


func _row_label(variant: String) -> String:
	return variant + ("\n" + VARIANT_SCALES[variant] if VARIANT_SCALES.has(variant) else "")


func _find_head(prefix: String) -> int:
	var lib := Wardrobe.library()
	var head := -1
	for i in lib.head_count():
		if String(lib.head(i).display_name).begins_with(prefix):
			head = i
	return head


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## The viewport's current frame, cropped to the head and scaled to one cell (the
## shot_face_head.gd crop, so the framing matches cast_heads.png at any cell size).
func _grab(cell: int) -> Image:
	await _frames(2)
	var img := _vp.get_texture().get_image()
	var side := int(SIZE.x * 0.86)
	var crop := img.get_region(Rect2i((SIZE.x - side) / 2, (SIZE.y - side) / 2, side, side))
	crop.resize(cell, cell, Image.INTERPOLATE_LANCZOS)
	return crop


## Lay out [image or null, position, label, label width] on paper and save it. A null
## image is a row label, written at the row's middle.
func _save(cells: Array, size: Vector2i, file: String) -> void:
	var board := ColorRect.new()
	board.color = PAPER
	board.size = Vector2(size)
	for c: Array in cells:
		var pos: Vector2 = c[1]
		var lab := Label.new()
		lab.text = c[2]
		lab.size = Vector2(float(c[3]), LABEL_H * (3 if c[0] == null else 1))
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_color_override("font_color", INK)
		if c[0] == null:
			lab.position = pos + Vector2(0, 100)
			lab.add_theme_font_size_override("font_size", 28)
		else:
			var img: Image = c[0]
			var tr := TextureRect.new()
			tr.texture = ImageTexture.create_from_image(img)
			tr.position = pos
			board.add_child(tr)
			lab.position = pos + Vector2(0, img.get_height())
			lab.add_theme_font_size_override("font_size", 16)
		board.add_child(lab)
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(board)
	root.add_child(vp)
	await _frames(4)
	var path := OUT_DIR + "/" + file
	var err := vp.get_texture().get_image().save_png(path)
	vp.queue_free()
	print("Saved %s (%s)" % [path, error_string(err)])
