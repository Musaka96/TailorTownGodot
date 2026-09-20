extends SceneTree

## Headless regression test for the location layer: Locations id/scene mapping, the
## new-game flow through Mr. Hemming's apprenticeship into grandpa's shop, and that a
## save/load round trip at grandpa's carries the right location.
##   godot --headless --path . --script res://tools/test_locations.gd
##
## Every scene change (new_game, declining the tutorial, load_from) goes behind the
## LoadingCurtain, which takes real time to warm up and settle. Following test_session.gd's
## lead, this polls for the curtain's visibility / the current scene's path rather than
## waiting a fixed number of frames.

## A numbered slot, matching what the task and the pause menu use — writes go to
## user://saves_tools (never the player's real saves) because this runs via --script.
const SLOT := 1
const PATIENCE_MS := 15000

var _failures: Array[String] = []
var _hemming_scene := ""
var _grandpa_scene := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	for _i in 3:
		await process_frame

	var locations: Node = root.get_node("Locations")
	_hemming_scene = locations.scene_of(&"hemming")
	_grandpa_scene = locations.scene_of(&"grandpa")

	_test_pure_locations(locations)
	await _test_direct_boot()
	await _test_new_game_flow()
	await _test_save_round_trip()

	_finish()


# --- a. Locations id/scene mapping ------------------------------------------


func _test_pure_locations(locations: Node) -> void:
	_check(locations.scene_of(&"grandpa") == _grandpa_scene, "scene_of(grandpa) -> grandpa's shop")
	_check(locations.scene_of(&"hemming") == _hemming_scene, "scene_of(hemming) -> main.tscn")
	_check(
		locations.scene_of(&"nonsense") == _hemming_scene, "scene_of(unknown id) -> legacy hemming"
	)
	_check(locations.valid("") == &"hemming", "valid('') -> hemming")
	_check(locations.valid("grandpa") == &"grandpa", "valid('grandpa') -> grandpa")
	_check(locations.valid("bogus") == &"hemming", "valid(bogus) -> legacy hemming")

	# A save dict with no "location" key (an old, pre-locations save) resolves via the same
	# path SaveManager.load_from uses: Locations.scene_of(Locations.valid(data.get(...))).
	var no_location: Dictionary = {}
	_check(
		locations.scene_of(locations.valid(no_location.get("location", ""))) == _hemming_scene,
		"a save dict without a 'location' key maps to main.tscn"
	)

	locations.sync_to_scene(_grandpa_scene)
	_check(locations.current == &"grandpa", "sync_to_scene(grandpa path) sets current = grandpa")
	locations.sync_to_scene(_hemming_scene)
	_check(locations.current == &"hemming", "sync_to_scene(main.tscn) sets current = hemming")


# --- b. Direct boot of main.tscn --------------------------------------------


func _test_direct_boot() -> void:
	var sm: Node = root.get_node("SaveManager")
	var scene_res: PackedScene = load(_hemming_scene)
	var main: Node = scene_res.instantiate()
	root.add_child(main)
	# --script boots don't set current_scene on their own; SaveManager.notify_game_ready
	# (called from main.gd._ready) reads it, so set it before _ready fires.
	current_scene = main
	await process_frame
	await process_frame

	_check(sm.can_save(), "direct boot of main.tscn: can_save() is true")
	_check(not sm.kept_indoors(), "direct boot of main.tscn: kept_indoors() is false")
	_check(main.find_child("DoorBar", true, false) == null, "direct boot of main.tscn: no DoorBar")

	main.queue_free()
	await process_frame
	current_scene = null


# --- c. new_game(): apprenticeship at Hemming's, then arrival at grandpa's --


func _test_new_game_flow() -> void:
	var sm: Node = root.get_node("SaveManager")
	var locations: Node = root.get_node("Locations")
	var tut: Node = root.get_node("Tutorial")
	var cfg: Node = root.get_node("Config")
	var gs: Node = root.get_node("GameState")

	sm.new_game()
	await _until(func() -> bool: return _scene_path() == _hemming_scene and tut._layer != null)
	_check(_scene_path() == _hemming_scene, "new_game(): lands on main.tscn (Hemming's)")
	_check(tut._layer != null, "new_game(): the tutorial offer is up")

	_check(not sm.can_save(), "at Hemming's: can_save() is false")
	_check(sm.kept_indoors(), "at Hemming's: kept_indoors() is true")
	_check(not sm.save_to(SLOT), "at Hemming's: save_to(1) returns false")
	var hemming: Node = current_scene
	_check(
		hemming != null and hemming.find_child("DoorBar", true, false) != null,
		"at Hemming's: a DoorBar exists"
	)
	_check(locations.current == &"hemming", "at Hemming's: Locations.current == hemming")

	tut._on_prompt_answer(1)  # "No thanks" — decline the tutorial
	await _until(func() -> bool: return _scene_path() == _grandpa_scene)
	await _until(func() -> bool: return not _curtain_visible(sm))

	_check(_scene_path() == _grandpa_scene, "declining the tutorial: arrives at grandpa's shop")
	_check(locations.current == &"grandpa", "at grandpa's: Locations.current == grandpa")
	_check(sm.can_save(), "at grandpa's: can_save() is true")
	_check(not sm.kept_indoors(), "at grandpa's: kept_indoors() is false")
	var grandpa: Node = current_scene
	_check(
		grandpa != null and grandpa.find_child("DoorBar", true, false) == null,
		"at grandpa's: no DoorBar"
	)

	var expected_money := 500
	if cfg != null and cfg.data != null:
		expected_money = int(cfg.data.starting_money)
	_check(int(gs.money) == expected_money, "at grandpa's: money == the configured starting money")

	if grandpa == null:
		return
	var shelf: Node = grandpa.find_children("*", "Shelf", true, false)[0]
	_check(shelf.stored.size() == 2, "at grandpa's: the shelf holds the 2 starter rolls")

	for expect: String in [
		"Shelf", "Phone", "Worktable", "SewingMachine", "ClothingRack", "Mirror", "TrashCan"
	]:
		_check(
			grandpa.find_child(expect, true, false) != null,
			"at grandpa's: %s station exists" % expect
		)
	for absent: String in ["ApprenticeBench", "CoffeeMachine", "IroningBoard", "Mannequin"]:
		_check(
			grandpa.find_child(absent, true, false) == null,
			"at grandpa's: %s does not exist (that's Hemming's)" % absent
		)


# --- d. Save round trip at grandpa's -----------------------------------------


func _test_save_round_trip() -> void:
	var sm: Node = root.get_node("SaveManager")
	var locations: Node = root.get_node("Locations")

	var snap: Dictionary = sm.capture("locations test")
	_check(
		str(snap.get("location", "")) == "grandpa", "capture() at grandpa's: location == 'grandpa'"
	)
	_check(sm.save_to(SLOT), "save_to(1) succeeds at grandpa's")

	sm.load_from(SLOT)
	await _until(func() -> bool: return _curtain_visible(sm))
	await _until(func() -> bool: return not _curtain_visible(sm))

	_check(_scene_path() == _grandpa_scene, "load_from(1): ends up in the grandpa scene again")
	_check(locations.current == &"grandpa", "load_from(1): Locations.current == grandpa")

	var saved_path := ProjectSettings.globalize_path("user://saves_tools/slot_%d.sav" % SLOT)
	if FileAccess.file_exists(saved_path):
		DirAccess.remove_absolute(saved_path)


# --- helpers ------------------------------------------------------------------


func _scene_path() -> String:
	return current_scene.scene_file_path if current_scene != null else ""


func _curtain_visible(sm: Node) -> bool:
	for child in sm.get_children():
		if child is CanvasLayer and (child as CanvasLayer).visible:
			return true
	return false


## Wait until `done` holds, or give up after PATIENCE_MS (the check that follows then fails).
func _until(done: Callable) -> void:
	var deadline := Time.get_ticks_msec() + PATIENCE_MS
	while not done.call() and Time.get_ticks_msec() < deadline:
		await process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("test_locations: ALL PASS")
		quit(0)
	else:
		print("test_locations: %d FAILURE(S)" % _failures.size())
		quit(1)
