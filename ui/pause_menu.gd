extends Control

## In-game pause overlay — built in code by ui.gd and parented to the UI layer.
## Shows on GameState.pause_toggled(true). This is the home for Save / Load: it
## lists SaveManager's slots and writes or reads the chosen one. Processes while
## the tree is paused (PROCESS_MODE_ALWAYS) so its buttons stay live.

var _box: VBoxContainer
var _title: Label
var _sub := false  # true while a Save/Load slot list is showing (Esc goes back)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()
	GameState.pause_toggled.connect(_on_pause)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	center.add_child(panel)
	Style.apply_skin(panel, Style.MenuSkin.ORDER)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Style.S3)
	panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", Style.S3)
	margin.add_child(outer)

	_title = Style.title_label("Paused", Style.BRASS)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(_title)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", Style.S2)
	outer.add_child(_box)


func _on_pause(paused: bool) -> void:
	visible = paused
	if paused:
		set_process_unhandled_input(true)  # re-arm (a prior Load/Menu disabled it)
		_show_main()


func _unhandled_input(event: InputEvent) -> void:
	var vp := get_viewport()
	if not visible or vp == null:
		return
	# Esc backs out of a slot list to the main pause page (instead of unpausing).
	if _sub and event.is_action_pressed("pause"):
		_show_main()
		vp.set_input_as_handled()
		return
	if MenuKit.handle_nav(event, _box):
		vp.set_input_as_handled()


func _show_main() -> void:
	_sub = false
	_clear()
	_title.text = "Paused"
	_box.add_child(MenuKit.button("Resume", _resume))
	_box.add_child(MenuKit.button("Save Game", func() -> void: _show_slots(true)))
	_box.add_child(MenuKit.button("Load Game", func() -> void: _show_slots(false)))
	_box.add_child(MenuKit.button("Main Menu", _to_menu))
	_box.add_child(MenuKit.button("Quit to Desktop", func() -> void: get_tree().quit()))
	_focus_first()


func _show_slots(saving: bool) -> void:
	_sub = true
	_clear()
	_title.text = "Save to a slot" if saving else "Load a save"
	for info: Dictionary in SaveManager.slot_infos():
		var slot: Variant = info["slot"]
		if saving:
			_box.add_child(MenuKit.slot_row(info, func() -> void: _save(slot)))
		elif bool(info.get("exists", false)):
			_box.add_child(MenuKit.slot_row(info, func() -> void: _load(slot)))
		else:
			var empty := MenuKit.slot_row(info, Callable())
			empty.disabled = true
			_box.add_child(empty)
	_box.add_child(MenuKit.button("Back", _show_main))
	_focus_first()


func _save(slot: Variant) -> void:
	var day := Shift.day if Shift != null else 1
	if SaveManager.save_to(slot, "Day %d" % day):
		UI.toast("Saved to slot %s" % str(slot))
	else:
		UI.toast("Save failed")
	_show_main()


func _load(slot: Variant) -> void:
	set_process_unhandled_input(false)  # stop reacting while the scene swaps
	GameState.is_paused = false
	SaveManager.load_from(slot)


func _to_menu() -> void:
	set_process_unhandled_input(false)  # stop reacting while the scene swaps
	GameState.is_paused = false
	SaveManager.to_menu()


func _resume() -> void:
	GameState.is_paused = false


func _clear() -> void:
	# queue_free (not free): _clear runs from a button's own pressed handler, and a
	# node can't be freed while it's mid-emit. Hide now so the container drops it
	# from layout this frame and the new buttons don't briefly overlap the old.
	for child in _box.get_children():
		child.hide()
		child.queue_free()


func _focus_first() -> void:
	await get_tree().process_frame
	for child in _box.get_children():
		if child is Button and child.visible and not child.disabled:
			child.grab_focus()
			return
