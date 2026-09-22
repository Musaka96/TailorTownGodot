extends SceneTree

## Headless test for reading the Handbook: W/S turn to the previous/next topic at once,
## however long the article is; E turns the article's pages, wrapping to the top after
## the last; the page marker names the page and is gone on a one-page article; a held
## key never flicks through the topics; a new topic opens at its top.
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
	var pager: Label = _book.get("_pager")
	var pill: Control = _book.get("_page_pill")
	_check(pager != null and pager.visible, "a long article shows its page marker")
	_check(pill != null and pill.visible, "and the E pill in the hint bar")
	var pages := int(_book.call("_page_count"))
	_check(pages >= 2, "(setup) it runs to 2+ pages")
	_check(pager.text == "Page 1 of %d" % pages, "the marker starts on page 1 of them")

	await _press("move_back")
	_check(int(_book.get("_topic")) == topic + 1, "S turns to the next topic at once")
	await process_frame
	_check(art.scroll_vertical == 0, "the next topic opens at its top")
	await _press("move_forward")
	_check(int(_book.get("_topic")) == topic, "W turns back")

	for _i in 6:  # held S: echoes never turn the page
		await _press("move_back", true)
	_check(int(_book.get("_topic")) == topic, "a held key never flicks through the topics")

	await _press("interact")
	_check(art.scroll_vertical > 0, "E turns to the next page of the article")
	_check(int(_book.get("_topic")) == topic, "and stays on the same topic")
	_check(pager.text == "Page 2 of %d" % pages, "the marker says page 2")
	for _i in pages - 2:
		await _press("interact")
	_check(art.scroll_vertical >= int(bar.max_value - bar.page) - 2, "E reaches the last page")
	_check(pager.text == "Page %d of %d" % [pages, pages], "the marker says so")
	await _press("interact")
	_check(art.scroll_vertical == 0, "after the last page, E goes back to the top")

	var short := _shortest_anywhere()
	_book.set("_chapter", short.x)
	_book.set("_topic", short.y)
	_book.call("_refresh")
	for _i in 4:
		await process_frame
	_check(bar.max_value - bar.page < 2.0, "(setup) the shortest article fits its page")
	_check(not pager.visible, "a one-page article has no page marker")
	_check(not pill.visible, "nor an E pill")
	await _press("interact")
	_check(art.scroll_vertical == 0, "and E leaves it where it is")
	_finish()


## The Dress Codes topic with the longest article — not the last, so there is a topic
## after it to turn to.
func _longest_topic() -> int:
	var entries: Array = (_book.get("_chapters") as Array)[0]["entries"]
	var best := 0
	for i in entries.size():
		if str(entries[i]["body"]).length() > str(entries[best]["body"]).length():
			best = i
	return mini(best, entries.size() - 2)


## (chapter, topic) of the shortest article in the whole book.
func _shortest_anywhere() -> Vector2i:
	var chapters: Array = _book.get("_chapters")
	var best := Vector2i.ZERO
	var best_len := -1
	for c in chapters.size():
		var entries: Array = chapters[c]["entries"]
		for t in entries.size():
			var n := str(entries[t]["body"]).length()
			if best_len < 0 or n < best_len:
				best_len = n
				best = Vector2i(c, t)
	return best


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
	# Real time, not frames: headless frames fly, and the page turn is a timed tween.
	await create_timer(0.3).timeout
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
