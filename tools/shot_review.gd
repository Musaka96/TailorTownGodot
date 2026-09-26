extends SceneTree

## Review sheets for everything the character system produces, dressed through the real
## game path: CustomerManager._dress (customers) / Player._dress (the shopkeeper),
## FaceCast (which paper face + hair colour + glasses a name wears), Wardrobe.street_look
## (street clothes) and CustomerPortrait (the dialogue-bubble view). Nothing here sets a
## FaceStyle or outfit directly. NOT headless (it renders):
##   godot --path . --script res://tools/shot_review.gd
## Writes to IMPORT/faces_proc/ (git-ignored):
##   review_cast.png         player + every FaceCast.BY_NAME cast member + Mr. Hemming
##                            (mentor): head close-up, dialogue portrait, full body
##   review_pedestrians.png  24 random passers-by (4 seeds x 6, re-seeded until at least
##                            8 wear glasses and every street outfit shows up): full body
##                            in a 6x4 grid, then the same 24 as head close-ups
##   review_expressions.png  player, Mr. Dimmock, Mr. Pettigrew, Miss Hartley x the 7
##                            shared face states, on their real dressed heads
##   feminine.png            the feminine kit (FaceCast.style() for a woman: lashes and
##                            lipstick): the cast women and three female passers-by, before
##                            (FaceCast.feminine_kit off) and after, head close-up and
##                            dialogue portrait, then the kit on a blink and talking
## After `--`: `feminine` or `pedestrians` renders only that sheet.

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const CUSTOMER_SCENE := "res://entities/customer/customer.tscn"
const MANAGER_SCRIPT := "res://entities/customer/customer_manager.gd"
const PREF_SCRIPT := "res://data/scripts/customer_preference.gd"
const PORTRAIT_SCRIPT := "res://ui/customer_portrait.gd"
const MENTOR_SCRIPT := "res://ui/tutorial/mentor_dialog.gd"

const OUT_DIR := "res://IMPORT/faces_proc"
const SIZE := Vector2i(900, 900)
const BG_COLOR := Color(0.5, 0.55, 0.62)
const PAPER := Color("f7f1e6")
const INK := Color("3a2418")
const FOOTER_H := 34

# --- shared camera framing ---------------------------------------------------
const HEAD_DIST := 2.2
const HEAD_FOV := 35.0
const BODY_FOV := 30.0
const CROP_SIDE_FRAC := 0.8  # close-up: fraction of the render that is the head crop

# --- sheet 1: the cast --------------------------------------------------------
const HEAD_CELL := 420
const DIALOGUE_SIZE := 260  # CustomerPortrait.VIEW_SIZE
const BODY_CELL := 260
const TITLE_H := 54
const SUB_H := 34
const CAST_NAMES := [
	"Mr. Dimmock",
	"Mr. Pettigrew",
	"Mrs. Applegarth",
	"Ms. Portobello",
	"Mr. Zanetti",
	"Mr. Bellamy",
	"Miss Hartley",
	"Mr. Rossi",
	"Mr. Penrose",
	"Dr. Vance",
	"Lady Ashcombe",
	"Lord Tewkesbury",
]
const SEED_CAST := 4200

# --- sheet 2: pedestrians ------------------------------------------------------
const PED_SEED_BASE := 9001
const PED_PER_SEED := 6
const PED_SEED_COUNT := 4
const PED_COLS := 6
const PED_ROWS := 4  # PED_SEED_COUNT * PED_PER_SEED / PED_COLS
const PED_MIN_GLASSES := 8
const PED_BODY_TARGET := 260
const PED_HEAD_TARGET := 220
const PED_COL_W := 240
const PED_LABEL_H := 58
const PED_HEAD_LABEL_H := 24
const PED_HEADER_H := 30

# --- sheet 3: expressions ------------------------------------------------------
const EXPR_ROWS := ["player", "Mr. Dimmock", "Mr. Pettigrew", "Miss Hartley"]
const EXPR_STATE_CODES := ["", "blink_half", "closed", "happy", "sad", "surprised", "talking"]
const EXPR_STATE_NAMES := ["idle", "blink_half", "closed", "happy", "sad", "surprised", "talking"]
const EXPR_CELL := 200
const EXPR_COL_W := 220
const EXPR_ROW_LABEL_W := 150
const EXPR_LABEL_H := 26
const EXPR_SETTLE_FRAMES := 18  # > PROC_EXPR_TIME (0.18s) worth of frames

# --- sheet 4: the feminine kit --------------------------------------------------
const FEM_CAST := ["Ms. Portobello", "Miss Hartley", "Mrs. Applegarth", "Lady Ashcombe"]
const FEM_PASSERS := 3
const FEM_CELL := 280
const FEM_LABEL_H := 30
const FEM_STATES := ["blink_half", "talking"]

var _vp: SubViewport
var _world: Node3D
var _cam: Camera3D


func _initialize() -> void:
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 0.95)
	env.ambient_light_energy = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -32, 0)
	_world.add_child(sun)
	_cam = Camera3D.new()
	_world.add_child(_cam)
	_cam.current = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("feminine"):
		await _sheet_feminine()
	elif args.has("pedestrians"):
		await _sheet_pedestrians()
	else:
		await _sheet_cast()
		await _sheet_pedestrians()
		await _sheet_expressions()
		await _sheet_feminine()
	quit(0)


# --- Sheet 1: the cast ---------------------------------------------------------


func _sheet_cast() -> void:
	var cells := []
	var col_w := float(HEAD_CELL)
	var x := 0.0

	var player: Node3D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	player.set_physics_process(false)
	_world.add_child(player)
	await _frames(4)
	var combo: int = player.call("_usable_combo")
	var pmodel: Node = player.get_node("Model")
	var phead := await _close_up(pmodel, HEAD_CELL)
	var psmall := await _close_up(pmodel, DIALOGUE_SIZE)
	var pbody := await _full_body(pmodel, BODY_CELL)
	_column(
		cells,
		x,
		col_w,
		"player",
		phead,
		"paper_j1, head %d" % combo,
		psmall,
		"no in-game dialogue portrait\n(close-up shown instead)",
		pbody,
		(
			"suit %s\njacket style %d, trouser style %d"
			% [player.suit_cloth, player.jacket_style, player.trouser_style]
		)
	)
	x += col_w
	player.queue_free()
	await _frames(2)

	var manager: Node = load(MANAGER_SCRIPT).new()
	var pref_cls: GDScript = load(PREF_SCRIPT)
	var rng: RandomNumberGenerator = manager.get("_rng")
	var cast_log := PackedStringArray()
	for i in CAST_NAMES.size():
		var nm: String = CAST_NAMES[i]
		rng.seed = SEED_CAST + i
		var cust: Node3D = (load(CUSTOMER_SCENE) as PackedScene).instantiate()
		_world.add_child(cust)
		cust.set_physics_process(false)
		cust.preference = pref_cls.random_pref(rng, nm)
		manager.call("_dress", cust)
		await _frames(3)
		var rig: Node = cust.get_node("Rig")
		var head_img := await _close_up(rig, HEAD_CELL)
		var dlg_img := await _dialogue_portrait(cust, {})
		var body_img := await _full_body(rig, BODY_CELL)
		var has_glasses: bool = str(cust.glasses) != ""
		var glasses_txt: String = str(cust.glasses) if has_glasses else "none"
		var head_label := "preset %s\nhead %d" % [cust.face_style, int(cust.head_index)]
		var body_label := (
			"glasses %s (%s)\nstreet %d/%d"
			% [glasses_txt, cust.glasses_color, int(cust.street_index), int(cust.street_color)]
		)
		_column(
			cells,
			x,
			col_w,
			nm,
			head_img,
			head_label,
			dlg_img,
			"dialogue portrait (CustomerPortrait)",
			body_img,
			body_label
		)
		cast_log.append(
			(
				"%s: preset=%s glasses=%s(%s) head=%d street=%d/%d"
				% [
					nm,
					cust.face_style,
					glasses_txt,
					cust.glasses_color,
					int(cust.head_index),
					int(cust.street_index),
					int(cust.street_color)
				]
			)
		)
		x += col_w
		cust.queue_free()
		await _frames(2)
	for line: String in cast_log:
		print(line)

	var mentor: Node = load(MENTOR_SCRIPT).new()
	var look: Dictionary = mentor.call("_look")
	mentor.free()
	var portrait: Control = load(PORTRAIT_SCRIPT).new()
	root.add_child(portrait)
	await _frames(2)
	portrait.call("configure_look", look)
	portrait.call("set_live", true)
	var mrig: Node3D = portrait.get("_rig")
	(mrig.get("_blink") as Timer).stop()
	mrig.call("set_talking", false)
	await _frames(8)
	var mview: SubViewport = portrait.get("_view")
	var mdlg_img := mview.get_texture().get_image()
	mview.remove_child(mrig)
	_world.add_child(mrig)
	portrait.queue_free()
	await _frames(3)
	var mhead_img := await _close_up(mrig, HEAD_CELL)
	var mbody_img := await _full_body(mrig, BODY_CELL)
	_column(
		cells,
		x,
		col_w,
		"Mr. Hemming (mentor)",
		mhead_img,
		"preset %s, via _look()" % str(look.get("face_style", "")),
		mdlg_img,
		"dialogue portrait (CustomerPortrait)",
		mbody_img,
		"tweed suit, via _look()"
	)
	mrig.queue_free()
	x += col_w
	manager.free()

	var size := Vector2i(
		int(x),
		int(TITLE_H + HEAD_CELL + SUB_H + DIALOGUE_SIZE + SUB_H + BODY_CELL + SUB_H + FOOTER_H)
	)
	var footer := (
		"cast RNG seed base %d (per-member seed = base + index); heads reproducible across runs"
		% SEED_CAST
	)
	await _save_sheet(cells, size, "review_cast.png", footer)


## One column: title, head close-up + label, dialogue image + label, body image + label.
func _column(
	cells: Array,
	x: float,
	col_w: float,
	title: String,
	head_img: Image,
	head_label: String,
	dialogue_img: Image,
	dialogue_label: String,
	body_img: Image,
	body_label: String
) -> void:
	_label_at(cells, title, Vector2(x, 0), col_w, 16)
	var head_y := TITLE_H
	_img_at(cells, head_img, Vector2(x + (col_w - head_img.get_width()) * 0.5, head_y))
	_label_at(cells, head_label, Vector2(x, head_y + HEAD_CELL), col_w, 12)
	var dlg_y := head_y + HEAD_CELL + SUB_H
	if dialogue_img != null:
		_img_at(cells, dialogue_img, Vector2(x + (col_w - dialogue_img.get_width()) * 0.5, dlg_y))
	_label_at(cells, dialogue_label, Vector2(x, dlg_y + DIALOGUE_SIZE), col_w, 12)
	var body_y := dlg_y + DIALOGUE_SIZE + SUB_H
	if body_img != null:
		_img_at(cells, body_img, Vector2(x + (col_w - body_img.get_width()) * 0.5, body_y))
	_label_at(cells, body_label, Vector2(x, body_y + BODY_CELL), col_w, 12)


# --- Sheet 2: pedestrians -------------------------------------------------------


func _sheet_pedestrians() -> void:
	var manager: Node = load(MANAGER_SCRIPT).new()
	var rng: RandomNumberGenerator = manager.get("_rng")
	var outfit_count: int = Wardrobe.library().street_outfits.size()
	var seeds := _pick_pedestrian_seeds(manager, rng, outfit_count)

	var body_cells := []
	var head_cells := []
	var glasses_n := 0
	var outfits_seen := {}
	var idx := 0
	var log_lines := PackedStringArray()
	for sd in seeds:
		rng.seed = int(sd)
		for k in PED_PER_SEED:
			var cust: Node3D = (load(CUSTOMER_SCENE) as PackedScene).instantiate()
			_world.add_child(cust)
			cust.set_physics_process(false)
			manager.call("_dress", cust)
			await _frames(3)
			var rig: Node = cust.get_node("Rig")
			var has_glasses: bool = str(cust.glasses) != ""
			if has_glasses:
				glasses_n += 1
			outfits_seen[int(cust.street_index)] = true
			var body_img := await _full_body(rig, PED_BODY_TARGET)
			var head_img := await _close_up(rig, PED_HEAD_TARGET)
			var col := idx % PED_COLS
			var row := int(idx / PED_COLS)
			var label := (
				"seed %d #%d: %s%s\n%s, street %d/%d, head %d"
				% [
					int(sd),
					k + 1,
					cust.face_style,
					" (F)" if int(cust.gender) == 2 else "",
					str(cust.glasses) if has_glasses else "no glasses",
					int(cust.street_index),
					int(cust.street_color),
					int(cust.head_index)
				]
			)
			var bx := col * PED_COL_W + (PED_COL_W - body_img.get_width()) * 0.5
			var by := PED_HEADER_H + row * (PED_BODY_TARGET + PED_LABEL_H)
			_img_at(body_cells, body_img, Vector2(bx, by))
			_label_at(
				body_cells, label, Vector2(col * PED_COL_W, by + PED_BODY_TARGET), PED_COL_W, 11
			)
			var hx := col * PED_COL_W + (PED_COL_W - head_img.get_width()) * 0.5
			var hy := PED_HEADER_H + row * (PED_HEAD_TARGET + PED_HEAD_LABEL_H)
			_img_at(head_cells, head_img, Vector2(hx, hy))
			_label_at(
				head_cells,
				"seed %d #%d" % [int(sd), k + 1],
				Vector2(col * PED_COL_W, hy + PED_HEAD_TARGET),
				PED_COL_W,
				11
			)
			log_lines.append(label.replace("\n", " "))
			idx += 1
			cust.queue_free()
			await _frames(1)
	manager.free()
	for line: String in log_lines:
		print(line)
	print(
		(
			"pedestrians: %d/%d wear glasses; street outfits seen: %s (library has %d)"
			% [glasses_n, PED_COLS * PED_ROWS, str(outfits_seen.keys()), outfit_count]
		)
	)

	var width := PED_COLS * PED_COL_W
	var body_grid_h := PED_HEADER_H + PED_ROWS * (PED_BODY_TARGET + PED_LABEL_H)
	var head_grid_h := PED_HEADER_H + PED_ROWS * (PED_HEAD_TARGET + PED_HEAD_LABEL_H)
	var cells := []
	_label_at(cells, "full body (6x4)", Vector2(0, 0), width, 18)
	cells.append_array(body_cells)
	var head_offset := body_grid_h
	_label_at(cells, "head close-ups (same 24)", Vector2(0, head_offset), width, 18)
	for c: Dictionary in head_cells:
		var moved: Dictionary = c.duplicate()
		moved["pos"] = (c["pos"] as Vector2) + Vector2(0, head_offset)
		cells.append(moved)
	var size := Vector2i(width, int(head_offset + head_grid_h + FOOTER_H))
	var footer := (
		"seeds %s; %d/%d wear glasses; street outfits seen: %s of %d"
		% [str(seeds), glasses_n, PED_COLS * PED_ROWS, str(outfits_seen.keys()), outfit_count]
	)
	await _save_sheet(cells, size, "review_pedestrians.png", footer)


## Four consecutive seeds (PED_SEED_BASE and up, stepping by 4) whose 24 passers-by
## (dressed by the real _dress) give at least PED_MIN_GLASSES in glasses and touch every
## street outfit the library has, found by simulating _dress on a throwaway probe (no
## rendering) so the render pass only ever dresses the customers it will shoot.
func _pick_pedestrian_seeds(manager: Node, rng: RandomNumberGenerator, outfit_count: int) -> Array:
	var probe: Node3D = (load(CUSTOMER_SCENE) as PackedScene).instantiate()
	_world.add_child(probe)
	probe.set_physics_process(false)
	var base := PED_SEED_BASE
	var tries := 0
	while tries < 2000:
		var seeds: Array = [base, base + 1, base + 2, base + 3]
		var glasses := 0
		var outfits := {}
		for sd in seeds:
			rng.seed = int(sd)
			for k in PED_PER_SEED:
				manager.call("_dress", probe)
				if str(probe.glasses) != "":
					glasses += 1
				outfits[int(probe.street_index)] = true
		if glasses >= PED_MIN_GLASSES and outfits.size() >= outfit_count:
			probe.queue_free()
			return seeds
		base += 4
		tries += 1
	probe.queue_free()
	push_warning("shot_review: could not find seeds meeting the glasses/outfit mix; using base")
	return [PED_SEED_BASE, PED_SEED_BASE + 1, PED_SEED_BASE + 2, PED_SEED_BASE + 3]


# --- Sheet 3: expressions -------------------------------------------------------


func _sheet_expressions() -> void:
	var manager: Node = load(MANAGER_SCRIPT).new()
	var pref_cls: GDScript = load(PREF_SCRIPT)
	var rng: RandomNumberGenerator = manager.get("_rng")
	var cells := []
	var width := EXPR_ROW_LABEL_W + EXPR_STATE_NAMES.size() * EXPR_COL_W
	for c in EXPR_STATE_NAMES.size():
		_label_at(
			cells,
			EXPR_STATE_NAMES[c],
			Vector2(EXPR_ROW_LABEL_W + c * EXPR_COL_W, 0),
			EXPR_COL_W,
			15
		)
	var y := EXPR_LABEL_H
	for row in EXPR_ROWS.size():
		var who_name: String = EXPR_ROWS[row]
		var owner_node: Node3D
		var rig: Node
		if who_name == "player":
			owner_node = (load(PLAYER_SCENE) as PackedScene).instantiate()
			owner_node.set_physics_process(false)
			_world.add_child(owner_node)
			await _frames(4)
			rig = owner_node.get_node("Model")
		else:
			owner_node = (load(CUSTOMER_SCENE) as PackedScene).instantiate()
			owner_node.set_physics_process(false)
			_world.add_child(owner_node)
			var idx := CAST_NAMES.find(who_name)
			rng.seed = SEED_CAST + maxi(idx, 0)
			owner_node.preference = pref_cls.random_pref(rng, who_name)
			manager.call("_dress", owner_node)
			await _frames(3)
			rig = owner_node.get_node("Rig")
		var blink: Timer = rig.get("_blink")
		if blink != null:
			blink.stop()
		_label_at(cells, who_name, Vector2(0, y), EXPR_ROW_LABEL_W, 14)
		for c in EXPR_STATE_CODES.size():
			rig.call("_proc_expression", EXPR_STATE_CODES[c])
			await _frames(EXPR_SETTLE_FRAMES)
			var img := await _close_up(rig, EXPR_CELL)
			var ix := EXPR_ROW_LABEL_W + c * EXPR_COL_W + (EXPR_COL_W - EXPR_CELL) * 0.5
			_img_at(cells, img, Vector2(ix, y))
		y += EXPR_CELL + EXPR_LABEL_H
		owner_node.queue_free()
		await _frames(2)
	manager.free()
	var size := Vector2i(width, int(y + FOOTER_H))
	var footer := "states via CharacterRig._proc_expression() / FaceStyle.expression(); idle = rest"
	await _save_sheet(cells, size, "review_expressions.png", footer)


# --- Sheet 4: the feminine kit ----------------------------------------------------


## FEM_CAST and the first FEM_PASSERS women among fresh passers-by (one _dress per seed from
## PED_SEED_BASE), each dressed twice through the real path from the same seed: the kit off,
## then on. Rows: close-up and dialogue before, close-up and dialogue after, then the kit in
## FEM_STATES (close-ups).
func _sheet_feminine() -> void:
	var manager: Node = load(MANAGER_SCRIPT).new()
	var pref_cls: GDScript = load(PREF_SCRIPT)
	var rng: RandomNumberGenerator = manager.get("_rng")
	# [label, seed, name ("" = a passer-by)]
	var who := []
	for nm: String in FEM_CAST:
		who.append([nm, SEED_CAST + CAST_NAMES.find(nm), nm])
	var probe: Node3D = (load(CUSTOMER_SCENE) as PackedScene).instantiate()
	_world.add_child(probe)
	probe.set_physics_process(false)
	var sd := PED_SEED_BASE
	while who.size() < FEM_CAST.size() + FEM_PASSERS and sd < PED_SEED_BASE + 500:
		rng.seed = sd
		manager.call("_dress", probe)
		if int(probe.gender) == 2:
			who.append(["passer-by, seed %d" % sd, sd, ""])
		sd += 1
	probe.queue_free()
	var rows := ["before", "before, dialogue", "after", "after, dialogue"] + FEM_STATES
	var cells := []
	var row_h := FEM_CELL + FEM_LABEL_H
	for c in who.size():
		var x := float(c * FEM_CELL)
		_label_at(cells, str(who[c][0]), Vector2(x, 0), FEM_CELL, 14)
		for kit in [false, true]:
			FaceCast.feminine_kit = kit
			var cust: Node3D = (load(CUSTOMER_SCENE) as PackedScene).instantiate()
			_world.add_child(cust)
			cust.set_physics_process(false)
			rng.seed = int(who[c][1])
			if str(who[c][2]) != "":
				cust.preference = pref_cls.random_pref(rng, str(who[c][2]))
			manager.call("_dress", cust)
			await _frames(3)
			var rig: Node = cust.get_node("Rig")
			var r0 := 2 if kit else 0
			var face := FaceCast.preset_of(rig.get("face_style"))
			var y := FEM_LABEL_H + r0 * row_h
			_img_at(cells, await _close_up(rig, FEM_CELL), Vector2(x, y))
			_label_at(cells, "%s: %s" % [rows[r0], face], Vector2(x, y + FEM_CELL), FEM_CELL, 11)
			y += row_h
			var dlg := await _dialogue_portrait(cust, {})
			_img_at(cells, dlg, Vector2(x + (FEM_CELL - dlg.get_width()) * 0.5, y))
			_label_at(cells, rows[r0 + 1], Vector2(x, y + FEM_CELL), FEM_CELL, 11)
			for s in FEM_STATES.size() if kit else 0:
				rig.call("_proc_expression", FEM_STATES[s])
				await _frames(EXPR_SETTLE_FRAMES)
				y = FEM_LABEL_H + (4 + s) * row_h
				_img_at(cells, await _close_up(rig, FEM_CELL), Vector2(x, y))
				_label_at(cells, FEM_STATES[s], Vector2(x, y + FEM_CELL), FEM_CELL, 11)
			cust.queue_free()
			await _frames(2)
	FaceCast.feminine_kit = true
	manager.free()
	var size := Vector2i(FEM_CELL * who.size(), int(FEM_LABEL_H + rows.size() * row_h + FOOTER_H))
	var footer := (
		"lash %.3f, lipstick #%s (FaceCast.LASH / LIPSTICK); cast seeds as review_cast.png"
		% [FaceCast.LASH, FaceCast.LIPSTICK.to_html(false)]
	)
	await _save_sheet(cells, size, "feminine.png", footer)


# --- Shared render helpers -------------------------------------------------------


## The rig's head from the front, framed on the head bone, resized to `cell` px square.
func _close_up(rig: Node, cell: int) -> Image:
	var blink: Timer = rig.get("_blink")
	if blink != null:
		blink.stop()
	var skel := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	var head := (rig as Node3D).global_position + Vector3(0, 1.5, 0)
	if skel != null:
		var bone := skel.find_bone("head_2")
		if bone >= 0:
			head = skel.global_transform * skel.get_bone_global_pose(bone).origin
	var at := head + Vector3(0, 0.36, 0)
	_cam.fov = HEAD_FOV
	_cam.look_at_from_position(at + Vector3(0, 0, HEAD_DIST), at, Vector3.UP)
	await _frames(4)
	var img := _vp.get_texture().get_image()
	var side := int(SIZE.x * CROP_SIDE_FRAC)
	var crop := img.get_region(Rect2i((SIZE.x - side) / 2, (SIZE.y - side) / 2, side, side))
	crop.resize(cell, cell, Image.INTERPOLATE_LANCZOS)
	return crop


## The rig full length, front on, cropped tight around the figure and resized to `target_h`
## px tall (width follows, whatever the crop's aspect gives).
func _full_body(rig: Node, target_h: int) -> Image:
	var blink: Timer = rig.get("_blink")
	if blink != null:
		blink.stop()
	var skel := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	var base: Vector3 = (rig as Node3D).global_position
	var head_top := base.y + 1.7
	if skel != null:
		var bone := skel.find_bone("head_2")
		if bone >= 0:
			# The head_2 bone sits at the jaw/neck, well under the crown of a chibi head's
			# puffy hair (confirmed by rendering raw, uncropped: a 0.16 m margin clipped the
			# top of the hair on every rig tried). 0.5 m clears it with room to spare; the
			# autocrop below trims whatever margin is left over, so a generous guess here
			# never leaves background in the final image, only a bug would.
			head_top = (skel.global_transform * skel.get_bone_global_pose(bone).origin).y + 0.5
	var body_h := maxf(head_top - base.y, 1.2)
	var aim := Vector3(base.x, base.y + body_h * 0.5, base.z)
	_cam.fov = BODY_FOV
	var half_fov := deg_to_rad(BODY_FOV * 0.5)
	var visible_h := body_h * 1.6
	var dist := visible_h / (2.0 * tan(half_fov))
	_cam.look_at_from_position(aim + Vector3(0, 0, dist), aim, Vector3.UP)
	await _frames(4)
	var img := _vp.get_texture().get_image()
	var cropped := _autocrop(img, BG_COLOR, 0.05, 14)
	var scale := float(target_h) / maxf(float(cropped.get_height()), 1.0)
	var w := maxi(1, int(round(cropped.get_width() * scale)))
	cropped.resize(w, target_h, Image.INTERPOLATE_LANCZOS)
	return cropped


## Crop to the bounding box of pixels that differ from `bg` by more than `tol` (checked on
## a small downsampled copy, for speed), padded by `pad` px; the whole image if nothing
## differs enough to find a subject.
func _autocrop(img: Image, bg: Color, tol: float, pad: int) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var sw := mini(w, 180)
	var sh := maxi(1, int(round(float(h) * sw / w)))
	var small := img.duplicate() as Image
	small.resize(sw, sh, Image.INTERPOLATE_NEAREST)
	var min_x := sw
	var min_y := sh
	var max_x := -1
	var max_y := -1
	var tol2 := tol * tol
	for y in sh:
		for x in sw:
			var c := small.get_pixel(x, y)
			var dr := c.r - bg.r
			var dg := c.g - bg.g
			var db := c.b - bg.b
			if dr * dr + dg * dg + db * db > tol2:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return img
	var sx := float(w) / sw
	var sy := float(h) / sh
	var x0 := maxi(0, int(min_x * sx) - pad)
	var y0 := maxi(0, int(min_y * sy) - pad)
	var x1 := mini(w, int((max_x + 1) * sx) + pad)
	var y1 := mini(h, int((max_y + 1) * sy) + pad)
	return img.get_region(Rect2i(x0, y0, x1 - x0, y1 - y0))


## The dialogue portrait (CustomerPortrait) for a customer, or a plain look when `cust`
## is null.
func _dialogue_portrait(cust: Node, look: Dictionary) -> Image:
	var portrait: Control = load(PORTRAIT_SCRIPT).new()
	root.add_child(portrait)
	await _frames(2)
	if cust != null:
		portrait.call("configure", cust)
	else:
		portrait.call("configure_look", look)
	portrait.call("set_live", true)
	var rig: Node = portrait.get("_rig")
	(rig.get("_blink") as Timer).stop()
	rig.call("set_talking", false)
	await _frames(8)
	var view: SubViewport = portrait.get("_view")
	var img := view.get_texture().get_image()
	portrait.queue_free()
	return img


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _img_at(cells: Array, img: Image, pos: Vector2) -> void:
	cells.append({"kind": "img", "img": img, "pos": pos})


func _label_at(cells: Array, text: String, pos: Vector2, w: float, font_size: int) -> void:
	cells.append({"kind": "label", "text": text, "pos": pos, "w": w, "font": font_size})


func _save_sheet(cells: Array, size: Vector2i, file: String, footer: String) -> void:
	var board := ColorRect.new()
	board.color = PAPER
	board.size = Vector2(size)
	for c: Dictionary in cells:
		if c["kind"] == "img":
			var img: Image = c["img"]
			var tr := TextureRect.new()
			tr.texture = ImageTexture.create_from_image(img)
			tr.position = c["pos"]
			board.add_child(tr)
		else:
			var lab := Label.new()
			lab.text = c["text"]
			lab.position = c["pos"]
			lab.size = Vector2(c["w"], 64)
			lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lab.autowrap_mode = TextServer.AUTOWRAP_WORD
			lab.add_theme_color_override("font_color", INK)
			lab.add_theme_font_size_override("font_size", int(c["font"]))
			board.add_child(lab)
	if footer != "":
		var f := Label.new()
		f.text = footer
		f.position = Vector2(10, size.y - FOOTER_H)
		f.size = Vector2(size.x - 20, FOOTER_H)
		f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		f.add_theme_color_override("font_color", INK)
		f.add_theme_font_size_override("font_size", 14)
		board.add_child(f)
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
