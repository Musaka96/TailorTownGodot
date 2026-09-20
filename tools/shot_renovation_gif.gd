extends SceneTree

## Frames for a GIF of grandpa's shop being brought back, start to finish, by the real
## procedure: every cleanup spot cleared one by one, every building job ordered (the
## builders' clutter appears) and then finished at dawn, and at the end the room upgrades.
## NOT headless. Writes .dev/reno_gif/frame_NNN.png + manifest.json (file, caption, ms);
## tools/make_renovation_gif.py turns those into the GIF.
##   godot --path . --script res://tools/shot_renovation_gif.gd

const SCENE := "res://scenes/world/grandpa/main_grandpa.tscn"
const OUT_DIR := "res://.dev/reno_gif"
const SIZE := Vector2i(960, 540)
const LOOK_AT := Vector3(3.15, 0.0, 1.75)  # the middle of both buildings
const CAM_FROM := Vector3(3.15, 16.1, 11.85)  # high over the street, looking in and down
const BUILD := 1  # Renovation.Kind.BUILD

var _reno: Node
var _main: Node
var _camera: Camera3D
var _frames: Array = []
var _day := 1


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
	ui.visible = false  # the shop is the subject; captions are added when the GIF is made
	_reno = root.get_node("Renovation")
	_reno.reset()
	var rep: Node = root.get_node("Reputation")
	rep.points = int(rep.TIERS[rep.TIERS.size() - 1]["at"])  # no waiting for a name
	root.get_node("GameState").money = 999999
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_main.add_child(_camera)
	_camera.look_at_from_position(CAM_FROM, LOOK_AT)
	for _i in 60:  # let the roof fade and the grade settle
		_camera.current = true
		await process_frame

	await _shoot("Grandpa's shop, the first morning", 1800)
	for id: String in _reno.all_ids():
		var d: Dictionary = _reno.data(id)
		var title := str(d.get("name", id))
		if int(d.get("kind", BUILD)) == BUILD:
			if not _reno.order(id):
				push_error("could not order %s" % id)
				continue
			var nights := int(_reno.nights_left(id))
			await _shoot(
				"%s — builders in (%d night%s)" % [title, nights, "" if nights == 1 else "s"], 900
			)
			for _n in nights:
				_day += 1
				root.get_node("EventBus").day_began.emit(_day)
			await _shoot("%s — done" % title, 1300)
		else:
			var spots := int(d.get("spots", 1))
			for i in spots:
				_reno.clear_spot(id)
				var last := i == spots - 1
				var note := "done" if last else "%d of %d" % [i + 1, spots]
				await _shoot("%s — %s" % [title, note], 1100 if last else 450)
	var upgrades: Node = root.get_node("Upgrades")
	for id: String in ["shop_coffee", "shop_iron", "apprentice"]:
		upgrades.debug_set(id, true)
	upgrades.changed.emit()
	await _shoot("Coffee, pressing and an apprentice move in", 2600)

	var f := FileAccess.open(OUT_DIR + "/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_frames, "  "))
	f.close()
	print("renovation gif: %d frames in %s" % [_frames.size(), OUT_DIR])
	quit()


## Let the change reach the screen, then keep the frame with its caption and hold time.
func _shoot(caption: String, ms: int) -> void:
	for _i in 4:
		_camera.current = true
		await process_frame
	var file := "frame_%03d.png" % _frames.size()
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + "/" + file))
	_frames.append({"file": file, "caption": caption, "ms": ms})
