extends SceneTree

## Preview of the new worktable and sewing machine (IMPORT/town_kit/build_stations_v1.py) in
## grandpa's shop, in place of the old models, with their upgrades shown one at a time.
## Nothing is saved: the old models are only hidden for the shot. NOT headless.
##   godot --path . --script res://tools/shot_station_preview.gd
## Writes .dev/stations_v1/<station>_<shot>.png; a PIL snippet makes the contact sheets.

const SCENE := "res://scenes/world/grandpa/main_grandpa.tscn"
const DIR := "res://IMPORT/town_kit/export/stations_v1/"
const OUT_DIR := "res://.dev/stations_v1"
const SIZE := Vector2i(640, 400)
## station node in ShopRoom -> [new glb, the old model node to hide, where the new one sits
## in the station's space so it covers the old one's footprint, manifest key]
const STATIONS := {
	"Worktable": ["worktable_v1.glb", "RadniSto", Vector3(0.03, 0, 0.31), "worktable"],
	"SewingMachine": ["sewing_v1.glb", "MasinaZaSivenje", Vector3(0.07, 0, 0.3), "sewing"],
}
## The close-up camera, in the station's space: in front, up, looking down at the top.
const EYE := Vector3(0.0, 1.95, 1.75)
const LOOK := Vector3(0.0, 0.8, 0.25)
## The game camera's own view (scenes/camera/camera_rig.tscn: 55 degrees down, 7.66 m out),
## in world space from the station, as the player sees it.
const GAME_EYE := Vector3(0.0, 6.27, 4.39)

var _main: Node
var _camera: Camera3D
var _manifest: Dictionary


func _initialize() -> void:
	_run()


func _run() -> void:
	DisplayServer.window_set_size(SIZE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_manifest = JSON.parse_string(FileAccess.get_file_as_string(DIR + "stations_v1.json"))
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
	root.get_node("Renovation").debug_finish_all()
	var player := get_first_node_in_group("player") as Node3D
	player.global_position = Vector3(8.0, player.global_position.y, 9.0)  # out of the way
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_main.add_child(_camera)
	for station: String in STATIONS:
		await _film(station)
	print("shot_station_preview: done")
	quit(0)


func _film(station: String) -> void:
	var spec: Array = STATIONS[station]
	var host := _main.get_node("ShopRoom/" + station) as Node3D
	var old := host.get_node_or_null(str(spec[1])) as Node3D
	var model: Node3D = (load(DIR + str(spec[0])) as PackedScene).instantiate()
	model.position = spec[2]
	host.add_child(model)
	_camera.global_transform = Transform3D.IDENTITY
	_camera.look_at_from_position(host.to_global(EYE), host.to_global(LOOK))
	_camera.current = true
	var rules: Dictionary = _manifest[str(spec[3])]
	# the old model, for comparison
	model.visible = false
	await _shot(station, "0_old")
	if old != null:
		old.visible = false
	model.visible = true
	_apply(model, rules, [])
	await _shot(station, "1_base")
	_apply(model, rules, rules.keys())
	await _shot(station, "2_all")
	_camera.look_at_from_position(host.global_position + GAME_EYE, host.to_global(LOOK))
	var roofs: GDScript = load("res://scenes/world/roof_manager.gd")
	roofs.watch(host.global_position)  # the roof goes as if the player stood at the station
	_apply(model, rules, [])
	await _shot(station, "90_game_base")
	_apply(model, rules, rules.keys())
	await _shot(station, "91_game_all")
	roofs.unwatch()
	_camera.look_at_from_position(host.to_global(EYE), host.to_global(LOOK))
	var i := 3
	for id: String in rules:
		_apply(model, rules, [id])
		await _shot(station, "%d_%s" % [i, id])
		i += 1
	model.queue_free()
	if old != null:
		old.visible = true


## Show the base with the upgrades in `owned`: each shows its parts and takes away the base
## parts it replaces.
func _apply(model: Node3D, rules: Dictionary, owned: Array) -> void:
	model = model.find_child("Base", true, false).get_parent() as Node3D  # the glTF's root empty
	for child in model.get_children():
		var part := child as Node3D
		if part == null:
			continue
		part.visible = not part.name.begins_with("Upg_")
	for id: Variant in owned:
		var rule: Dictionary = rules[id]
		for n: Variant in rule.get("show", []):
			(model.get_node(str(n)) as Node3D).visible = true
		for n: Variant in rule.get("hide", []):
			(model.get_node(str(n)) as Node3D).visible = false


func _shot(station: String, label: String) -> void:
	for _i in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s_%s.png" % [OUT_DIR, station, label]
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
