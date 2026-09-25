extends SceneTree

## Before/after sheet for the tie cloth (TieMaterial): the player (player.tscn, J1) in the
## single-breasted suit, "before" with the old flat matte tie, "after" with the live silk
## twill. Row 1 uses shot_live_cast.gd's studio light (grey backdrop, colour ambient, one
## sun); row 2 is the shop itself (main.tscn's own lights and environment), the player
## where the scene puts him. Per row: head and chest at portrait size, then the knot at
## three times the zoom. NOT headless:
##   godot --path . --script res://tools/shot_tie_fix.gd
## Writes IMPORT/faces_proc/tie_fix.png (git-ignored).

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const MAIN_SCENE := "res://main.tscn"
# loaded, not named: the cloth classes reach autoloads a --script cannot see at compile time
const TIE_SCRIPT := "res://entities/character/tie_material.gd"
const CLOTH_SCRIPT := "res://data/scripts/cloth_material.gd"
const OUT_DIR := "res://IMPORT/faces_proc"
const SIZE := Vector2i(700, 700)
const CELL := 360
const LABEL_H := 40
const FOV := 35.0
const ZOOM := 3.0
const BUST_DIST := 2.6
const PAPER := Color("f7f1e6")
const INK := Color("3a2418")

var _vp: SubViewport
var _world: Node3D
var _cam: Camera3D


func _initialize() -> void:
	DisplayServer.window_set_size(SIZE)
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
	env.background_color = Color(0.5, 0.55, 0.62)
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
	var cells := []
	var player: Node3D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	player.set("jacket_style", 0)  # single-breasted
	player.set_physics_process(false)
	_world.add_child(player)
	for c: Camera3D in player.find_children("*", "Camera3D", true, false):
		c.current = false  # the player's own follow camera
	_cam.current = true
	await _frames(3)
	player.process_mode = Node.PROCESS_MODE_DISABLED  # a still: no walking, turning or idle
	await _row(player.get_node("Model"), _cam, _vp, 0, "studio", cells)
	player.queue_free()
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED

	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(main)
	await _frames(3)
	var shop_player: Node = main.find_child("Player", true, false)
	shop_player.set("jacket_style", 0)
	shop_player.call("_dress")
	await _frames(3)
	shop_player.process_mode = Node.PROCESS_MODE_DISABLED
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.current = true
	await _row(shop_player.get_node("Model"), cam, root, 1, "shop", cells)
	await _save_grid(cells, 4, 2, "tie_fix.png")
	quit(0)


## One light set-up: bust and knot, before and after, on `row`.
func _row(rig: Node, cam: Camera3D, vp: Viewport, row: int, tag: String, cells: Array) -> void:
	var blink: Timer = rig.get("_blink")
	if blink != null:
		blink.stop()
	var tie := (rig.get("_top") as Dictionary).get("tie") as MeshInstance3D
	var color: Color = rig.get("tie_color")
	var skel := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	var bone := skel.find_bone("head_2")
	for after in [false, true]:
		# framed per shot: the idle animation keeps the rig moving
		var head := skel.global_transform * skel.get_bone_global_pose(bone).origin
		var fwd := skel.global_transform.basis.z.normalized()
		var knot := _knot(tie, skel)
		if after:
			load(TIE_SCRIPT).dress(tie, color)
		else:
			var flat: StandardMaterial3D = rig.call("_flat", color, 1.0)
			flat.next_pass = load(CLOTH_SCRIPT).outline_material()
			tie.material_override = flat
		var name := "after" if after else "before"
		var bust_at := head + Vector3(0, 0.1, 0)
		cam.fov = FOV
		cam.look_at_from_position(bust_at + fwd * BUST_DIST, bust_at, Vector3.UP)
		var col := 1 if after else 0
		cells.append([await _grab(vp), col, row, "%s, %s" % [tag, name]])
		cam.fov = FOV / ZOOM
		cam.look_at_from_position(knot + fwd * BUST_DIST, knot, Vector3.UP)
		cells.append([await _grab(vp), col + 2, row, "%s knot x3, %s" % [tag, name]])


## The knot: the top of the tie mesh (skinned, so its rest vertices through the skin's
## binds are near enough for framing), a fifth of the way down from its highest point.
func _knot(tie: MeshInstance3D, skel: Skeleton3D) -> Vector3:
	var aabb := tie.get_aabb()
	var top := aabb.position + Vector3(aabb.size.x * 0.5, aabb.size.y, aabb.size.z)
	var p := tie.global_transform * (top - Vector3(0, aabb.size.y * 0.2, 0))
	if skel.global_position.distance_to(p) > 3.0:  # a skinned AABB off in bind space
		p = skel.global_position + Vector3(0, 1.2, 0)
	return p


## The viewport's picture, the middle 80 % scaled to a cell.
func _grab(vp: Viewport) -> Image:
	await _frames(5)
	var img := vp.get_texture().get_image()
	var sz := img.get_size()
	var side := int(mini(sz.x, sz.y) * 0.8)
	var crop := img.get_region(Rect2i((sz.x - side) / 2, (sz.y - side) / 2, side, side))
	crop.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
	return crop


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Lay out [image, column, row, label] cells on paper and save the sheet.
func _save_grid(cells: Array, cols: int, rows: int, file: String) -> void:
	var size := Vector2i(CELL * cols, (CELL + LABEL_H) * rows)
	var board := ColorRect.new()
	board.color = PAPER
	board.size = Vector2(size)
	for c: Array in cells:
		var pos := Vector2(int(c[1]) * CELL, int(c[2]) * (CELL + LABEL_H))
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(c[0])
		tr.position = pos
		board.add_child(tr)
		var lab := Label.new()
		lab.text = c[3]
		lab.position = pos + Vector2(0, CELL)
		lab.size = Vector2(CELL, LABEL_H)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_color_override("font_color", INK)
		lab.add_theme_font_size_override("font_size", 14)
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
