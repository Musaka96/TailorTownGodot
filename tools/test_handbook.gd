extends SceneTree

## Headless test for reading the Handbook: on a long article, S scrolls the article down
## until it has been read to the end and only then turns to the next topic; W scrolls back
## up before turning back; a held (echo) key only ever scrolls; a new topic opens at its
## top.
##   godot --headless --path . --script res://tools/test_handbook.gd

var _failures: Array[String] = []
var _book: Control


func _initialize() -> void:
	_run()


func _run() -> void:
	change_scene_to_file("res://main.tscn")
	await process_frame
	await process_frame
	var ui: Node = root.get_node("UI")
	if ui.newspaper != null:
		ui.newspaper.close()
	_book = ui.handbook
	ui.open_handbook(get_first_node_in_group("player"))
	await process_frame
	var art: ScrollContainer = _book.get("_art_scroll")
	_check(art != null, "the article sits in a scroll the book keeps hold of")
	if art == null:
		_finish()
		return
	_book.set("_chapter", 0)  # Dress Codes
	_book.set("_topic", _longest_topic())
	_book.call("_refresh")
	for _i in 4:
		await process_frame
	var bar := art.get_v_scroll_bar()
	_check(bar.max_value - bar.page > 40.0, "(setup) the article is longer than the page")
	var topic: int = _book.get("_topic")

	await _press("move_back")
	_check(art.scroll_vertical > 0, "S scrolls the article down")
	_check(int(_book.get("_topic")) == topic, "and stays on the same topic")

	for _i in 20:  # held S: echoes scroll to the end but never turn the page
		await _press("move_back", true)
	_check(int(_book.get("_topic")) == topic, "a held key never turns the page")
	_check(art.scroll_vertical >= int(bar.max_value - bar.page) - 2, "it reaches the end")

	await _press("move_back")
	_check(int(_book.get("_topic")) == topic + 1, "read to the end, S turns to the next topic")
	await process_frame
	_check(art.scroll_vertical == 0, "the next topic opens at its top")

	await _press("move_forward")
	_check(int(_book.get("_topic")) == topic, "at the top, W turns back")
	_finish()


## The Dress Codes topic with the longest article.
func _longest_topic() -> int:
	var entries: Array = (_book.get("_chapters") as Array)[0]["entries"]
	var best := 0
	for i in entries.size():
		if str(entries[i]["body"]).length() > str(entries[best]["body"]).length():
			best = i
	return mini(best, entries.size() - 2)  # leave a topic after it to turn to


func _press(action: String, echo := false) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	var key := InputEventKey.new()  # echo lives on key events; the book asks the event
	key.keycode = KEY_S if action == "move_back" else KEY_W
	key.physical_keycode = key.keycode
	key.pressed = true
	key.echo = echo
	root.push_input(key if echo else ev)
	for _i in 12:
		await process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("test_handbook: ALL PASS")
		quit(0)
	else:
		print("test_handbook: %d FAILURE(S)" % _failures.size())
		quit(1)
