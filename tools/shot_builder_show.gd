extends SceneTree

## Frames of the builders' show (BuilderShow) through the game's own camera: the shop gets
## papered, then the workroom is rebuilt. NOT headless. Writes
## .dev/builder_show/<clip>_NNN.png; tools/make_renovation_gif.py-style PIL turns each clip
## into a GIF.
##   godot --path . --script res://tools/shot_builder_show.gd

const SCENE := "res://scenes/world/grandpa/main_grandpa.tscn"
const OUT_DIR := "res://.dev/builder_show"
const SIZE := Vector2i(640, 400)
const FRAME_EVERY := 4  # rendered frames between captures (~15 fps at 60)
## In story order: each clip finishes everything before its job (Renovation.PROJECTS order).
const CLIPS := {
	"window": ["front_window", 5.0],
	"lights": ["front_lights", 5.0],
	"paper": ["front_paper", 5.0],
	"paint": ["facade_paint", 5.0],
	"workroom": ["workroom_build", 7.0],
}

var _main: Node
var _reno: Node


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
	root.get_node("GameState").money = 99999
	_reno = root.get_node("Renovation")
	_reno.reset()
	for clip: String in CLIPS:
		await _film(clip, str(CLIPS[clip][0]), float(CLIPS[clip][1]))
	await _inside_workroom()
	print("shot_builder_show: done")
	quit(0)


## Finish everything before `job`, let the camera settle, order it and capture the show.
func _film(clip: String, job: String, seconds: float) -> void:
	while _reno.call("_debug_next") != job and _reno.call("_debug_next") != "":
		_reno.debug_finish_next()
	for _i in 60:
		await process_frame
	if not _reno.order(job):
		push_error("shot_builder_show: could not order %s" % job)
		return
	var frames := int(seconds * 60.0 / FRAME_EVERY)
	for n in frames:
		for _f in FRAME_EVERY:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s_%03d.png" % [OUT_DIR, clip, n]
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("shot_builder_show: %s done=%s" % [job, _reno.is_done(job)])


## The player walks into the finished workroom: the divider behind them should stand as a
## low wall (its upper half faded), not vanish.
func _inside_workroom() -> void:
	var player := get_first_node_in_group("player") as Node3D
	player.global_position = Vector3(-1.5, player.global_position.y, 0.4)
	for _i in 90:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/inside_workroom.png" % OUT_DIR
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
