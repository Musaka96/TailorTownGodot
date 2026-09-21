extends SceneTree

## Frames of the hands-on jobs playing out (RenovationFx): the player pulls a dust sheet,
## scoops a heap and prises the workroom boards, filmed close. NOT headless. Writes
## .dev/reno_fx/<clip>_NNN.png; a few lines of PIL turn each clip into a GIF.
##   godot --path . --script res://tools/shot_renovation_fx.gd

const SCENE := "res://scenes/world/grandpa/main_grandpa.tscn"
const OUT_DIR := "res://.dev/reno_fx"
const SIZE := Vector2i(640, 400)
const CAM_OFFSET := Vector3(0.0, 3.6, 3.9)
const FRAME_EVERY := 3  # rendered frames between captures (~20 fps at 60)
const CLIP_SECONDS := 2.0

var _main: Node
var _reno: Node
var _camera: Camera3D
var _player: Node3D


func _initialize() -> void:
	_run()


func _run() -> void:
	DisplayServer.window_set_size(SIZE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_main = load(SCENE).instantiate()
	root.add_child(_main)
	current_scene = _main
	root.get_node("Locations").sync_to_scene(SCENE)
	for _i in 3:
		await process_frame
	var ui: Node = root.get_node("UI")
	if ui.newspaper != null:
		ui.newspaper.close()
	ui.visible = false
	_reno = root.get_node("Renovation")
	_reno.reset()
	var rep: Node = root.get_node("Reputation")
	rep.points = int(rep.TIERS[1]["at"])
	_player = get_first_node_in_group("player") as Node3D
	_camera = Camera3D.new()
	_camera.fov = 45.0
	_main.add_child(_camera)
	var shell := _main.get_node("ShopRoom/GrandpaShell")

	var sheet := _main.get_node("ShopRoom/Worktable/DustSheet") as Node3D
	await _film("sheet", sheet, Vector3(-1.1, 0.0, 0.7))
	for _i in 3:
		_reno.clear_spot("front_sheets")
	var heap := shell.get_node("Spots/front_sweep").get_child(1) as Node3D
	await _film("heap", heap, Vector3(1.0, 0.0, 0.3))
	for _i in 3:
		_reno.clear_spot("front_sweep")
	var boards := shell.get_node("Blockers/Blocker_workroom") as Node3D
	await _film("boards", boards, Vector3(-0.9, 0.0, 0.9))
	print("shot_renovation_fx: done")
	quit(0)


## Stand the player `offset` from `host`, frame the two of them, press, and capture.
func _film(clip: String, host: Node3D, offset: Vector3) -> void:
	var at := host.global_position
	_player.global_position = Vector3(at.x + offset.x, _player.global_position.y, at.z + offset.z)
	_camera.look_at_from_position(at + offset * 0.5 + CAM_OFFSET, at + offset * 0.5)
	for _i in 30:
		_camera.current = true
		await process_frame
	host.get_node("Work").interact(null)
	var frames := int(CLIP_SECONDS * 60.0 / FRAME_EVERY)
	for n in frames:
		for _f in FRAME_EVERY:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s_%03d.png" % [OUT_DIR, clip, n]
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
