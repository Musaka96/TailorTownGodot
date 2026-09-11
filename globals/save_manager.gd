extends Node

## Save & load for the whole shop — autoloaded as "SaveManager".
##
## A save is one binary file per slot under user://saves. It holds the run-level
## state that lives on the autoloads (money, day, reputation, which news has run,
## the open order book) plus the physical contents of the shop read out of the
## current scene: every roll on the shelves, part on the racks, the mannequin's
## dressing, the worktable, loose deliveries on the floor and whatever's in the
## player's hands. Stations serialise themselves (save_state/load_state) via
## SaveCodec, so this manager just orchestrates.
##
## Flow: the main menu calls new_game() or load_from(slot); either resets/queues
## state and swaps to main.tscn. main.gd then calls notify_game_ready(), where a
## queued load is applied to the freshly built scene and the day's clock starts.
## In-game the pause menu calls save_to(slot) / load_from(slot) / to_menu().

const VERSION := 1
const DIR := "user://saves"
const SLOTS := 3
const AUTO_SLOT := "auto"
const MAIN_SCENE := "res://main.tscn"
const MENU_SCENE := "res://scenes/menu/main_menu.tscn"

## "" = booted straight into the game (tests/dev); "new"/"load" = came from the
## menu and there's first-frame work to do in notify_game_ready.
var _mode := ""
var _pending: Dictionary = {}
## Where in the saved day to resume the clock (0..1); set while applying a load.
var _resume_progress := 0.0
var _resume_day_money := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_dir()
	EventBus.shift_ended.connect(_on_shift_ended)


# --- Menu-facing API -------------------------------------------------------


## Start a fresh shop: reset the autoloads to their opening state and load the game.
func new_game() -> void:
	_reset_autoloads()
	_mode = "new"
	_pending = {}
	_change_scene(MAIN_SCENE)


## Queue slot `slot` and load the game; returns false if the slot is empty.
func load_from(slot: Variant) -> bool:
	var data := _read(slot)
	if data.is_empty():
		return false
	_pending = data
	_mode = "load"
	_change_scene(MAIN_SCENE)
	return true


## Capture the live shop and write it to `slot`; returns whether it was written.
func save_to(slot: Variant, save_name := "") -> bool:
	return _write(slot, capture(save_name))


## Leave the game and return to the main menu.
func to_menu() -> void:
	_mode = "menu"
	_pending = {}
	_change_scene(MENU_SCENE)


## Metadata for every numbered slot, for the slot list in the menus.
func slot_infos() -> Array:
	var out: Array = []
	for i in range(1, SLOTS + 1):
		out.append(_info(i))
	return out


## The most recently written slot id (numbered or autosave), or null if none.
func latest_slot() -> Variant:
	var best: Variant = null
	var best_time := ""
	for slot: Variant in _all_slot_ids():
		var data := _read(slot)
		if data.is_empty():
			continue
		var when := str(data.get("saved_at", ""))
		if best == null or when > best_time:
			best = slot
			best_time = when
	return best


func has_any_save() -> bool:
	return latest_slot() != null


# --- Game-scene lifecycle --------------------------------------------------


## Called from main.gd._ready. Applies a queued load to the fresh scene (or just
## kicks off a new day) and starts the clock. A no-op on a direct boot.
func notify_game_ready() -> void:
	var mode := _mode
	_mode = ""
	if UI != null:
		UI.visible = true  # reveal the HUD/newspaper now that a game is running
	match mode:
		"load":
			await _apply_pending()
			DayNight.start_shift(_resume_progress)  # resume the day where it was saved
			if Shift != null:
				Shift.set_day_baseline(_resume_day_money)
			get_tree().paused = false
		"new":
			await get_tree().process_frame
			if Tutorial != null:
				# Freeze the shop (no day, no newspaper) until the tutorial is chosen/skipped.
				get_tree().paused = true
				Tutorial.offer(_begin_new_day)
			else:
				_begin_new_day()
		_:
			# Booted straight into main.tscn (dev): start the day here since DayNight no
			# longer auto-starts at boot.
			if not DayNight.running:
				DayNight.start_shift()
			get_tree().paused = false


## Start the first day (called immediately for a fresh game, or once the tutorial prompt is
## answered so the newspaper never pops before the player has chosen).
func _begin_new_day() -> void:
	get_tree().paused = false
	DayNight.start_shift()


# --- Capture ---------------------------------------------------------------


## The whole shop as a plain dictionary, ready for _write.
func capture(save_name := "") -> Dictionary:
	var scene := get_tree().current_scene
	return {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"name": save_name,
		"money": GameState.money,
		"day": Shift.day if Shift != null else 1,
		"reputation": Reputation.points if Reputation != null else 0,
		"upgrades": Upgrades.save_state() if Upgrades != null else {},
		"clock": DayNight.progress() if DayNight != null else 0.0,
		"day_start_money": Shift.day_start_money() if Shift != null else GameState.money,
		"news_seen": News.seen_snapshot() if News != null else {},
		"orders": Orders.save_state(),
		"stations": _capture_stations(scene) if scene != null else {},
		"loose": _capture_loose(scene) if scene != null else [],
		"carry": _capture_carry(scene) if scene != null else {},
	}


## Persist every in-scene node that implements save_state/load_state, keyed by its scene
## path. Scanning by capability (not a fixed class list) means a new stateful station is
## saved automatically — no edit here needed.
func _capture_stations(scene: Node) -> Dictionary:
	var out := {}
	for node in scene.find_children("*", "Node", true, false):
		if node.has_method("save_state") and node.has_method("load_state"):
			out[str(scene.get_path_to(node))] = node.save_state()
	return out


func _capture_loose(scene: Node) -> Array:
	var out: Array = []
	for child in _shop_room(scene).get_children():
		if not SaveCodec.is_item(child):
			continue
		var d := SaveCodec.item_to(child)
		d["pos"] = child.global_position
		out.append(d)
	return out


func _capture_carry(scene: Node) -> Dictionary:
	var slot := _carry(scene)
	if slot == null or slot.get_held() == null:
		return {}
	return SaveCodec.item_to(slot.get_held())


# --- Apply -----------------------------------------------------------------


func _apply_pending() -> void:
	var d := _pending
	_pending = {}
	GameState.money = int(d.get("money", 500))
	Shift.day = int(d.get("day", 1))
	Reputation.points = int(d.get("reputation", 0))
	if Upgrades != null:
		Upgrades.restore(d.get("upgrades", {}))
	_resume_progress = float(d.get("clock", 0.0))
	_resume_day_money = int(d.get("day_start_money", GameState.money))
	if News != null:
		News.restore_seen(d.get("news_seen", {}))
	Orders.restore(d.get("orders", []))
	# One frame so the freshly swapped-in scene's stations have run _ready.
	await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene == null:
		return
	_restore_stations(scene, d.get("stations", {}))
	_restore_carry(scene, d.get("carry", {}))
	_restore_loose(scene, d.get("loose", []))


func _restore_stations(scene: Node, data: Dictionary) -> void:
	for path: String in data.keys():
		var node := scene.get_node_or_null(NodePath(path))
		if node != null and node.has_method("load_state"):
			node.load_state(data[path])


func _restore_carry(scene: Node, d: Dictionary) -> void:
	if d.is_empty():
		return
	var slot := _carry(scene)
	if slot == null:
		return
	var node := SaveCodec.item_from(d)
	if node == null:
		return
	scene.add_child(node)  # needs a parent before take_item reparents it to the hand
	slot.take_item(node)


func _restore_loose(scene: Node, arr: Array) -> void:
	var room := _shop_room(scene)
	# Clear the fresh scene's authored loose items (e.g. the starting roll) first.
	for child in room.get_children():
		if SaveCodec.is_item(child):
			child.queue_free()
	for d: Dictionary in arr:
		var node := SaveCodec.item_from(d)
		if node == null:
			continue
		room.add_child(node)
		node.global_position = d.get("pos", Vector3.ZERO)


# --- Helpers ---------------------------------------------------------------


func _reset_autoloads() -> void:
	var start := Config.data.starting_money if Config != null and Config.data != null else 500
	GameState.money = start
	Reputation.points = 0
	if Upgrades != null:
		Upgrades.reset()
	Orders.active.clear()
	Shift.day = 1
	if News != null:
		News.restore_seen({})
		News.current_fashion = null
		News.current_edition.clear()


func _change_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


func _shop_room(scene: Node) -> Node:
	var room := scene.get_node_or_null("ShopRoom")
	return room if room != null else scene


func _carry(scene: Node) -> Node:
	var found := scene.find_children("*", "CarrySlot", true, false)
	return found[0] if not found.is_empty() else null


func _on_shift_ended() -> void:
	var day := Shift.day if Shift != null else 1
	_write(AUTO_SLOT, capture("Autosave — end of day %d" % day))


# --- File I/O --------------------------------------------------------------


func _info(slot: Variant) -> Dictionary:
	var data := _read(slot)
	if data.is_empty():
		return {"slot": slot, "exists": false}
	return {
		"slot": slot,
		"exists": true,
		"day": int(data.get("day", 1)),
		"money": int(data.get("money", 0)),
		"reputation": int(data.get("reputation", 0)),
		"saved_at": str(data.get("saved_at", "")),
		"name": str(data.get("name", "")),
	}


func _all_slot_ids() -> Array:
	var ids: Array = []
	for i in range(1, SLOTS + 1):
		ids.append(i)
	ids.append(AUTO_SLOT)
	return ids


func _slot_path(slot: Variant) -> String:
	return "%s/slot_%s.sav" % [DIR, str(slot)]


func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		DirAccess.make_dir_recursive_absolute(DIR)


func _write(slot: Variant, data: Dictionary) -> bool:
	_ensure_dir()
	var f := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(data, false)
	f.close()
	return true


func _read(slot: Variant) -> Dictionary:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var value: Variant = f.get_var(false)
	f.close()
	return value if value is Dictionary else {}
