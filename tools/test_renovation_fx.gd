extends SceneTree

## The hands-on jobs play out instead of snapping: a press takes a moment, the thing the
## player pressed on is the one that goes, everything it was made of is put back for a
## reset, and the player can move again at the end.
##   godot --headless --path . --script res://tools/test_renovation_fx.gd

const SCENE := "res://scenes/world/grandpa/main_grandpa.tscn"

var _fails := 0
var _sections_ended := 0
var _reno: Node
var _state: Node
var _main: Node
var _director: Node3D
var _shell: Node3D


func _initialize() -> void:
	_run()


func _run() -> void:
	for _i in 3:
		await process_frame
	_reno = root.get_node("Renovation")
	_state = root.get_node("GameState")
	_main = load(SCENE).instantiate()
	root.add_child(_main)
	current_scene = _main
	root.get_node("Locations").sync_to_scene(SCENE)
	for _i in 4:
		await process_frame
	_director = _main.get_node("ShopRoom/RenovationDirector") as Node3D
	_shell = _main.get_node("ShopRoom/GrandpaShell") as Node3D
	_reno.reset()
	await process_frame

	await _the_sheet_picked_comes_off()
	await _the_picked_heap_goes()
	await _a_second_press_waits()
	await _window_boards_come_off()
	await _doorway_boards_open_the_room()
	_reset_brings_it_all_back()
	_check(_sections_ended == 6, "every section ran to its last line (%d of 6)" % _sections_ended)
	print("test_renovation_fx: %s" % ("ALL PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	quit(1 if _fails > 0 else 0)


## Press the LAST heap of the sweep: that heap goes, not the first one.
func _the_picked_heap_goes() -> void:
	while not _reno.is_done("front_sheets"):
		_reno.clear_spot("front_sheets")
	var holder := _shell.get_node("Spots/front_sweep")
	var picked := holder.get_child(holder.get_child_count() - 1) as Node3D
	var bit := picked.get_child(0) as Node3D
	var bit_at := bit.transform
	var started := Time.get_ticks_msec()
	await _press(picked)
	var took := Time.get_ticks_msec() - started
	_check(took >= 500, "clearing a heap takes a moment (%d ms)" % took)
	_check(took < 2000, "…but only a moment")
	_check(_reno.spots_cleared("front_sweep") == 1, "one spot counted")
	_check(not picked.visible, "the heap the player pressed is the one that went")
	var others_there := 0
	for spot in holder.get_children():
		if spot != picked and (spot as Node3D).visible:
			others_there += 1
	_check(others_there == holder.get_child_count() - 1, "…and the rest are still there")
	_check(bit.transform.is_equal_approx(bit_at), "its bits are put back where they lay")
	_check(picked.scale.is_equal_approx(Vector3.ONE), "…and the heap is its own size again")
	_check(not _state.input_locked, "the player can move again")
	_sections_ended += 1


func _a_second_press_waits() -> void:
	var holder := _shell.get_node("Spots/front_sweep")
	var a := holder.get_child(1) as Node3D
	var b := holder.get_child(2) as Node3D
	_work(a).interact(null)
	_work(b).interact(null)  # mashed while the first is still going
	await create_timer(2.0).timeout
	var cleared: int = _reno.spots_cleared("front_sweep")
	_check(cleared == 2, "a press mashed mid-job doesn't clear a second heap (%d)" % cleared)
	_check(b.visible, "…the second heap is still there")
	_sections_ended += 1


func _the_sheet_picked_comes_off() -> void:
	var rack := _main.get_node("ShopRoom/ClothingRack")
	var sheet := rack.get_node("DustSheet") as Node3D
	var sheet_at := sheet.transform
	await _press(sheet)
	_check(not sheet.visible, "the rack's sheet came off when the rack's was pulled")
	var table_sheet := _main.get_node("ShopRoom/Worktable/DustSheet") as Node3D
	_check(table_sheet.visible, "…and the worktable is still under its own")
	_check(sheet.transform.is_equal_approx(sheet_at), "the sheet is put back for a reset")
	_sections_ended += 1


func _window_boards_come_off() -> void:
	while not _reno.is_done("front_sweep"):
		_reno.clear_spot("front_sweep")
	var window := _shell.get_node("Spots/front_boards/Spot1") as Node3D
	_check(window.get_node_or_null("Interactable") != null, "a boarded window can be pressed")
	_check(_reno.available("front_boards"), "…once the sweep is done")
	var plank := window.get_child(0) as Node3D
	var plank_at := plank.transform
	await _press(window)
	_check(_reno.spots_cleared("front_boards") == 1, "one window unboarded")
	_check(not window.visible, "…the one pressed")
	_check(plank.transform.is_equal_approx(plank_at), "its planks are put back for a reset")
	_sections_ended += 1


func _doorway_boards_open_the_room() -> void:
	var guard := 0
	while not _reno.is_done("front_boards") and guard < 10:
		_reno.clear_spot("front_boards")
		guard += 1
	var blocker := _shell.get_node("Blockers/Blocker_workroom") as Node3D
	var why := (
		"done=%s needs=%s" % [_reno.is_done("workroom_boards"), _reno.needs_met("workroom_boards")]
	)
	_check(_reno.available("workroom_boards"), "the workroom boards can come off (%s)" % why)
	await _press(blocker)
	_check(_reno.is_done("workroom_boards"), "pulling the doorway boards finishes the job")
	_check(not blocker.visible, "…and the doorway is clear")
	_sections_ended += 1


func _reset_brings_it_all_back() -> void:
	_reno.reset()
	var holder := _shell.get_node("Spots/front_sweep")
	var all_back := true
	for spot in holder.get_children():
		all_back = all_back and (spot as Node3D).visible
	_check(all_back, "a reset brings every heap back")
	var blocker := _shell.get_node("Blockers/Blocker_workroom") as Node3D
	_check(blocker.visible, "…and the doorway boards")
	_check((blocker.get_node("Boards").get_child(0) as Node3D).visible, "…plank and all")
	_sections_ended += 1


func _press(host: Node3D) -> void:
	_work(host).interact(null)
	await create_timer(0.1).timeout
	var guard := 0
	while _state.input_locked and guard < 60:
		await create_timer(0.1).timeout
		guard += 1
	await process_frame


func _work(host: Node3D) -> Node:
	return host.get_node("Work")


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
