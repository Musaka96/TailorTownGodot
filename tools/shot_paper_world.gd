extends SceneTree

## The world in paper (scenes/world/PaperWorld, the owner's pick "G"), before and after.
## Boots the real shop (main.tscn, which attaches PaperWorld), stands the player by the
## sewing machine in the sun, and renders the same corner with PaperWorld off (a) and on
## (g), close up and from the gameplay camera. NOT headless:
##   godot --path . --script res://tools/shot_paper_world.gd -- [scout]
## scout: print where the stations stand and render an overview, nothing else.
## Writes to IMPORT/paper_world/ (git-ignored).

const OUT_DIR := "res://IMPORT/paper_world"
const SIZE := Vector2i(1600, 900)
const ROLL_SCENE := "res://entities/items/material_roll.tscn"
# the sunny corner
const SUN_ROT := Vector3(-36.0, 25.0, 0.0)
const PLAYER_POS := Vector3(-2.55, 0.0, -3.85)
const PLAYER_YAW := 0.35
const CLOSE_EYE := Vector3(-0.2, 2.6, 0.4)
const CLOSE_AT := Vector3(-3.7, 0.95, -4.6)
# bolts: material, position, rotation (degrees)
const ROLLS := [
	["navy_worsted_pinstripe", Vector3(-4.75, 0.3, -4.55), Vector3(0, 0, 8)],
	["burgundy_mohair_birdseye", Vector3(-4.45, 0.3, -4.75), Vector3(0, 30, -6)],
	["tan_linen_solid", Vector3(-4.95, 0.3, -4.2), Vector3(4, 0, 0)],
	["grey_tweed_herringbone", Vector3(-3.3, 0.13, -3.3), Vector3(0, 70, 90)],
	["blue_worsted_glencheck", Vector3(-3.05, 0.13, -3.05), Vector3(0, 55, 90)],
]

var _main: Node
var _cam: Camera3D
var _player: Node3D


func _initialize() -> void:
	DisplayServer.window_set_size(SIZE)
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	current_scene = _main
	await _frames(3)
	var ui := root.get_node_or_null("UI")
	if ui != null:
		if ui.get("newspaper") != null:
			ui.newspaper.close()
		ui.visible = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_player = _main.find_child("Player", true, false) as Node3D
	if args.has("scout"):
		await _scout()
		quit(0)
		return
	await _stage()
	await _frames(40)
	var pw := _main.get_node_or_null("PaperWorld")
	if args.has("probe"):
		await _frames(30)
		var seen := {}
		for mi: MeshInstance3D in _main.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				var m := mi.get_active_material(s)
				if m == null:
					continue
				var sh := ""
				if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
					sh = (m as ShaderMaterial).shader.resource_path.get_file()
				if sh == "paper_world.gdshader":
					continue
				var tr := ""
				if m is BaseMaterial3D:
					tr = str((m as BaseMaterial3D).transparency)
				var k := "%s %s '%s' tr=%s" % [m.get_class(), sh, m.resource_name, tr]
				seen[k] = (
					seen.get(k, "")
					if seen.has(k)
					else String(mi.get_path()).replace("/root/Main/", "")
				)
		for k in seen:
			print("LEFT ", k, " @ ", seen[k])
		quit(0)
		return
	for v: Array in [["a", false], ["g", true]]:
		if pw != null:
			pw.call("set_enabled", v[1])
		await _frames(30)  # the sweep reaches every mesh
		for close in [true, false]:
			_view(close)
			await _frames(8)
			_save("%s_%s.png" % ["close" if close else "game", v[0]])
	quit(0)


func _scout() -> void:
	for n in [
		"SewingMachine",
		"Worktable",
		"Shelf",
		"Bookshelf",
		"ClothingRack",
		"Mirror",
		"Phone",
		"TrashCan",
		"Player",
		"Sun",
		"DirectionalLight3D"
	]:
		var node := _main.find_child(n, true, false) as Node3D
		if node != null:
			print(
				"SCOUT %s pos=%s rot=%s" % [n, node.global_position, node.global_rotation_degrees]
			)
	_cam = Camera3D.new()
	_main.add_child(_cam)
	_cam.look_at_from_position(Vector3(0, 16, 6), Vector3(0, 0, 0), Vector3.UP)
	_cam.make_current()
	await _frames(40)
	_save("scout.png")


# --- staging -------------------------------------------------------------------------------


## The back-left corner: bookshelf, sewing machine, bin; the player by the machine turned
## toward the camera; a few bolts leaning and lying about; the sun low from the front right
## so it rakes both walls.
func _stage() -> void:
	var day := root.get_node_or_null("DayNight")
	if day != null:
		day.set_process(false)
	var sun := _main.find_child("Sun", true, false) as DirectionalLight3D
	if sun != null:
		sun.visible = true
		sun.rotation_degrees = SUN_ROT
		sun.light_energy = 1.15
		sun.light_color = Color(1.0, 0.95, 0.86)
		sun.shadow_enabled = true
	# the neighbours' houses stand in the way of a low sun: they stop casting for the test
	var town := _main.find_child("Town", true, false)
	if town != null:
		for g: GeometryInstance3D in town.find_children("*", "GeometryInstance3D", true, false):
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_player.set_physics_process(false)
	_player.set_process(false)
	_player.global_position = PLAYER_POS
	var model := _player.get("_model") as Node3D
	if model != null:
		model.rotation.y = PLAYER_YAW
	var rolls := Node3D.new()
	rolls.name = "PaperTestRolls"
	_main.add_child(rolls)
	for r: Array in ROLLS:
		var roll := (load(ROLL_SCENE) as PackedScene).instantiate() as Node3D
		roll.set("material", load("res://data/materials/%s.tres" % r[0]))
		rolls.add_child(roll)
		roll.global_position = r[1]
		roll.rotation_degrees = r[2]
		for b in roll.find_children("*", "RigidBody3D", true, false):
			(b as RigidBody3D).freeze = true
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_main.add_child(_cam)
	_cam.make_current()


func _view(close: bool) -> void:
	if close:
		_cam.fov = 40.0
		_cam.look_at_from_position(CLOSE_EYE, CLOSE_AT, Vector3.UP)
	else:
		# the gameplay camera's angle (camera_rig.tscn, x WorldScale 0.85), on the player
		_cam.fov = 75.0
		var at := PLAYER_POS + Vector3(0, 0.9, 0)
		_cam.look_at_from_position(PLAYER_POS + Vector3(0, 6.271, 4.393) * 0.85, at, Vector3.UP)


# --- output --------------------------------------------------------------------------------


func _save(file: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("%s/%s" % [OUT_DIR, file])
	img.save_png(path)
	print("SHOT ", path)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
