extends SceneTree

## Grandpa's keepsakes and letters: what the renovation turns up, what he writes about it,
## the shelf in the shop, and that none of it is lost or repeated across a save.
##   godot --headless --path . --script res://tools/test_story.gd

const SCENE := "res://scenes/world/grandpa/main_grandpa.tscn"
## How far into the shift to start the clock so the paper round has already been by
## (ui/newspaper.gd ARRIVES_AFTER is well under an hour of a nine-hour day).
const OPEN_A_WHILE := 0.15

var _fails := 0
var _sections_ended := 0
var _story: Node
var _reno: Node
var _main: Node
var _announced: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	for _i in 3:
		await process_frame
	_story = root.get_node("Story")
	_reno = root.get_node("Renovation")
	_story.letter_ready.connect(func(id: String) -> void: _announced.append(id))
	_main = load(SCENE).instantiate()
	root.add_child(_main)
	current_scene = _main
	root.get_node("Locations").sync_to_scene(SCENE)
	for _i in 4:
		await process_frame

	_data_is_sound()
	_finds_come_from_the_work()
	_old_saves_carry_their_finds_over()
	_the_shelf_fills()
	_letters_wait_their_turn()
	await _the_paper_queues_behind_the_letter()
	_save_round_trip()
	_check(_sections_ended == 7, "every section ran to its last line (%d of 7)" % _sections_ended)
	print("test_story: %s" % ("ALL PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	quit(1 if _fails > 0 else 0)


## Every keepsake hangs off a real job, and every letter off a real job or the arrival.
func _data_is_sound() -> void:
	var props: Dictionary = _main.get_node("ShopRoom/RenovationDirector").KEEPSAKE_PROPS
	for id: String in _story.KEEPSAKES:
		_check(_reno.data(id).has("name"), "keepsake '%s' hangs off a real job" % id)
		var k: Dictionary = _story.KEEPSAKES[id]
		_check(props.has(str(k["prop"])), "keepsake '%s' has something to stand on the shelf" % id)
		_check(str(k["text"]).length() > 80, "keepsake '%s' says something about him" % id)
	for id: String in _story.LETTERS:
		var after := str(_story.LETTERS[id].get("after", ""))
		_check(
			after == "" or not _reno.data(after).is_empty(), "letter '%s' waits on a real job" % id
		)
		_check(str(_story.LETTERS[id]["body"]).contains("Pops"), "letter '%s' is signed" % id)
	_sections_ended += 1


func _finds_come_from_the_work() -> void:
	_story.reset()
	_reno.reset()
	_check(_story.keepsake_count() == 0, "a fresh shop has nothing of his on the shelf")
	_check(not _story.has_found("front_sheets"), "…the shears included")
	for _i in 3:
		_reno.clear_spot("front_sheets")
	_check(_story.has_found("front_sheets"), "pulling the sheets off turns up his shears")
	_check(_story.keepsake_count() == 1, "…exactly one thing")
	_reno.restore({"done": ["front_sheets"]})
	_check(_story.keepsake_count() == 1, "restoring the same state finds nothing twice")
	_sections_ended += 1


## An older save found "workroom_clear" (the hand-cleared rubble); the builders do that
## room's whole job now, so an old find is carried over to "workroom_build" on load
## (Story.MOVED_KEEPSAKES).
func _old_saves_carry_their_finds_over() -> void:
	_story.restore({"found": ["workroom_clear"]})
	_check(not _story.has_found("workroom_clear"), "the old id itself is gone")
	_check(_story.has_found("workroom_build"), "…mapped onto the builders' job that replaced it")
	_check(_story.keepsake_count() == 1, "…exactly the one thing, not counted twice")
	# Put back what _finds_come_from_the_work left behind, for the sections after this one.
	_story.restore({"found": ["front_sheets"]})
	_sections_ended += 1


func _the_shelf_fills() -> void:
	var shelf := _main.get_node_or_null("ShopRoom/RenovationDirector/MemoryShelf") as Node3D
	_check(shelf != null, "there is a shelf on the wall")
	if shelf == null:
		return
	var shown := 0
	var hidden := 0
	for node in shelf.get_children():
		if not str(node.name).begins_with("Keepsake_"):
			continue
		if (node as Node3D).visible:
			shown += 1
		else:
			hidden += 1
	_check(shown == 1, "only the shears are standing on it")
	_check(hidden == _story.KEEPSAKES.size() - 1, "the rest are not there yet")
	_reno.debug_finish_all()
	var all_out := 0
	for node in shelf.get_children():
		if str(node.name).begins_with("Keepsake_") and (node as Node3D).visible:
			all_out += 1
	_check(all_out == _story.KEEPSAKES.size(), "a shop brought back has the lot on the shelf")
	_check(_story.shelf_text().contains("shears"), "and the shelf reads back what is on it")
	_sections_ended += 1


func _letters_wait_their_turn() -> void:
	_story.reset()
	_reno.reset()
	_announced.clear()
	_check(_story.next_letter() == "", "no letter waiting on a fresh run")
	root.get_node("EventBus").day_began.emit(1)
	_check(_story.next_letter() == "arrival", "the first morning: the letter that was on the mat")
	_check(_announced == ["arrival"], "…announced exactly once")
	root.get_node("EventBus").day_began.emit(2)
	_check(_announced == ["arrival"], "a second morning does not post it again")
	_story.mark_read("arrival")
	_check(_story.next_letter() == "", "once read it is off the pile")
	root.get_node("EventBus").day_began.emit(3)
	_check(_story.next_letter() == "", "…and never comes back")
	_reno.debug_finish_all()
	_check(_story.next_letter() != "", "finishing the shop earns the letters that follow")
	var earned := _announced.size()
	_check(earned > 1, "…several of them (%d)" % earned)
	_sections_ended += 1


## Day one, as the player meets it: the letter is on the mat, and the morning paper does
## not slide up underneath it. The paper waits for the shop to have been open a while,
## and then for the letter to be folded away.
func _the_paper_queues_behind_the_letter() -> void:
	var ui: Node = root.get_node("UI")
	var paper: Control = ui.newspaper
	var note: Control = ui.story_note
	var clock: Node = root.get_node("DayNight")
	var shift: Node = root.get_node("Shift")
	_story.reset()
	ui.close_all_menus()
	shift.reset_to(1)  # a fresh day 1, as a new game reaches it
	shift.begin_morning()  # dawn: the paper is printed, the sign still says CLOSED
	await _settle()
	_check(not paper.visible, "the paper is not on the mat at dawn")
	_check(note.visible, "grandpa's letter gets the quiet morning to itself")

	clock.start_shift(OPEN_A_WHILE)  # the sign is flipped, and the round has come by
	await _settle()
	_check(not paper.visible, "…and no paper slides up under the letter being read")

	note.close()
	await _settle()
	_check(paper.visible, "once the letter is folded away, the paper comes up")
	paper.close()
	clock.running = false
	_sections_ended += 1


## Long enough for the paper's delivery round to look twice (ui/newspaper.gd ROUND_POLL).
func _settle() -> void:
	await root.get_tree().create_timer(1.2).timeout


func _save_round_trip() -> void:
	_story.reset()
	_reno.reset()
	for _i in 3:
		_reno.clear_spot("front_sheets")
	root.get_node("EventBus").day_began.emit(1)
	var snap: Dictionary = _story.save_state()
	_story.reset()
	_check(_story.keepsake_count() == 0, "reset really empties it")
	snap["found"].append("not_a_project")
	snap["read"].append("not_a_letter")
	_story.restore(snap)
	_check(_story.has_found("front_sheets"), "restore brings his shears back")
	_check(_story.keepsake_count() == 1, "…and nothing that was never found")
	_check(_story.next_letter() == "arrival", "an unread letter is still waiting after a load")
	var shelf := _main.get_node_or_null("ShopRoom/RenovationDirector/MemoryShelf") as Node3D
	var thing := shelf.get_node_or_null("Keepsake_front_sheets") as Node3D
	_check(thing != null and thing.visible, "and the shop follows the restored state")
	_sections_ended += 1


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
