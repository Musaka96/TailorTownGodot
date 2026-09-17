extends SceneTree

## Headless smoke test for the boot path: the menu waits on its own theme, a new game comes
## up behind the LoadingCurtain, settles, opens and hands control back with the shop's music
## swelling in (globals/save_manager.gd, ui/loading_curtain.gd, globals/sfx.gd).
##   godot --headless --path . --script res://tools/test_boot.gd

var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	for _i in 6:
		await process_frame  # the autoloads are only really in the tree after a frame or two
	var saves: Node = root.get_node("SaveManager")
	var state: Node = root.get_node("GameState")
	var sfx: Node = root.get_node("Sfx")
	_check(_track(sfx) == sfx.MENU_THEME, "the main menu waits on its own theme")
	saves.new_game()
	await process_frame
	await process_frame
	var curtain: Node = _curtain(saves)
	_check(curtain != null and curtain.visible, "the curtain covers the screen while loading")
	_check(state.input_locked, "the player can't wander about behind it")
	var deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline and (curtain == null or curtain.visible):
		await process_frame
		curtain = _curtain(saves)
	_check(curtain != null and not curtain.visible, "the curtain lifts once the shop settled")
	# Control comes back the moment the curtain lifts — unless the mentor steps straight in
	# with the tutorial offer, which holds the input itself while he talks.
	var mentor_up: bool = bool(root.get_node("Tutorial").get("_talking"))
	_check(not state.input_locked or mentor_up, "control is handed back after the reveal")
	_check(root.get_node_or_null("Main") != null, "the shop is up and running")
	_check(_track(sfx) == sfx.THEME, "the shop's own music took over behind the curtain")
	_finish()


## Which library track the music player is on, or "" when it is silent.
func _track(sfx: Node) -> String:
	var music: AudioStreamPlayer = sfx.get("_music")
	if music == null or not music.playing:
		return ""
	var streams: Dictionary = sfx.get("_streams")
	for key: String in streams:
		var entry: Variant = streams[key]  # some keys hold a set of variants, not one stream
		if entry is AudioStream and entry == music.stream:
			return key
	return ""


func _curtain(saves: Node) -> Node:
	for child in saves.get_children():
		if child is CanvasLayer:
			return child
	return null


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("test_boot: ALL PASS")
		quit(0)
	else:
		print("test_boot: %d FAILURE(S)" % _failures.size())
		quit(1)
